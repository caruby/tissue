require 'singleton'
require 'caruby/helpers/log'
require 'caruby/helpers/collection'
require 'caruby/helpers/options'
require 'caruby/helpers/visitor'
require 'catissue/resource'
require 'catissue/database'
require 'catissue/helpers/controlled_value'

module CaTissue
  # This ControlledValues class loads caTissue permissible values from the database.
  # Use of this class requires the +dbi+ gem. See {CaRuby::SQLExecutor#initialize}
  # for a description of the database access properties.
  class ControlledValues
    include Singleton

    def initialize
      @executor = Database.instance.executor
      # The pid => { value => CV } that associates each loaded parent CV to its children.
      @pid_loaded_hash = LazyHash.new { |pid| load_pid_cvs(pid) }
      # The pid => { value => CV } that associates each fetched parent CV to its children.
      @pid_value_cv_hash = LazyHash.new do |pid|
        CaseInsensitiveHash.new { |hash, value| hash[value] = load_cv(pid, value) unless value.nil? }
      end
    end

    # Returns the transitive closure of each CV with the given public id and its children.
    # The CVs are loaded from the database if necessary.
    #
    # The following public id aliases are supported:
    # * +:tissue_site+
    # * +:clinical_diagnosis+
    #
    # @param [String, Symbol] public_id_or_alias the caTissue public id or an alias defined above
    # @return [<CaRuby::ControlledValue>] instances for the given public_id_or_alias
    def for_public_id(public_id_or_alias)
      pid = ControlledValue.standard_public_id(public_id_or_alias)
      @pid_loaded_hash[pid].values
    end

    # Returns the CV with the given public_id_or_alias and value. Loads the CV if necessary
    # from the database. The loaded CV does not have a parent or children.
    #
    # @param [String, Symbol] public_id_or_alias the caTissue public id or alias
    # @param [String] value the CV value
    # @param [Boolean] recursive whether to load the CV children as well.
    # @return [CaRuby::ControlledValue, nil] the matching CV, or nil if no match
    def find(public_id_or_alias, value, recursive=false)
      pid = ControlledValue.standard_public_id(public_id_or_alias)
      value_cv_hash = @pid_value_cv_hash[pid]
      cv = value_cv_hash[value]
      if recursive then
        fetch_descendants(cv, value_cv_hash)
      end
      cv
    end

    # Creates a new controlled value record in the database from the given ControlledValue cv.
    # The default identifier is the next identifier in the permissible values table.
    #
    # @param [ControlledValue] cv the controlled value to create
    # @return [ControlledValue] the created CV
    def create(cv)
      if cv.public_id.nil? then
        raise ArgumentError.new("Controlled value create is missing a public id")
      end
      if cv.value.nil? then
        raise ArgumentError.new("Controlled value create is missing a value")
      end
      cv.identifier ||= next_id
      logger.debug { "Creating controlled value #{cv} in the database..." }
      @executor.execute do |dbh|
        dbh.prepare(INSERT_STMT).execute(cv.identifier, cv.parent_identifier, cv.public_id, cv.value)
      end
      logger.debug { "Controlled value #{cv.public_id} #{cv.value} created with identifier #{cv.identifier}" }
      @pid_value_cv_hash[cv.public_id][cv.value] = cv
    end

    # Deletes the given ControlledValue record in the database. Recursively deletes the
    # transitive closure of children as well.
    #
    # @param [ControlledValue] cv the controlled value to delete
    def delete(cv)
      @executor.execute { |dbh| delete_recursive(cv, dbh.prepare(DELETE_STMT)) }
    end

    private

    PID_ROOTS_STMT = "select identifier, value from catissue_permissible_value where public_id = ? and (parent_identifier is null or parent_identifier = 0)"

    CHILDREN_STMT = "select identifier, value from catissue_permissible_value where parent_identifier = ?"

    INSERT_STMT = "insert into catissue_permissible_value (identifier, parent_identifier, public_id, value) values (?, ?, ?, ?)"

    DELETE_STMT = "delete from catissue_permissible_value where identifier = ?"

    MAX_ID_STMT = "select max(identifier) from catissue_permissible_value"

    SEARCH_STMT = "select identifier from catissue_permissible_value where value collate latin1_bin = ?"

    def load_pid_cvs(pid)
      fetch_cvs_with_public_id(pid, @pid_value_cv_hash[pid])
    end

    def load_cv(public_id, value)
      logger.debug { "Loading controlled value #{public_id} #{value} from the database..." }
      row = @executor.execute { |dbh| dbh.select_one(SEARCH_STMT, value) }
      logger.debug { "Controlled value #{public_id} #{value} not found." } and return if row.nil?
      identifier = row[0]
      logger.debug { "Controlled value #{public_id} #{value} loaded with identifier #{identifier}." }
      make_controlled_value(:identifier => identifier, :public_id => public_id, :value => value)
    end

    def next_id
      @executor.execute { |dbh| dbh.select_one(MAX_ID_STMT)[0].to_i } + 1
    end

    def delete_recursive(cv, sth)
      raise ArgumentError.new("Controlled value to delete is missing an identifier") if cv.identifier.nil?
      logger.debug { "Deleting controlled value #{cv} from the database..." }
      logger.debug { "Deleting controlled value #{cv} children: #{cv.children.pp_s}..." } unless cv.children.empty?
      cv.children.each { |child| delete_recursive(child, sth) }
      sth.execute(cv.identifier)
      @pid_value_cv_hash[cv.public_id].delete(cv.value)
      logger.debug { "Controlled value #{cv} deleted." }
    end

    # @param [String] pid the public id to find
    # @param [String => CaRuby::ControlledValue] the pid children value => CV hash
    def fetch_cvs_with_public_id(pid, value_cv_hash)
      logger.debug { "Loading #{pid} controlled values from the database..." }
      cvs = []
      @executor.execute do |dbh|
        dbh.select_all(PID_ROOTS_STMT, pid) do |row|
          identifier, value = row
          cvs << value_cv_hash[value] ||= make_controlled_value(:identifier => identifier, :public_id => pid, :value => value)
        end
        # load the root CVs children
        cvs.each { |cv| fetch_descendants(cv, value_cv_hash, dbh) }
      end
      logger.debug { "Loaded #{value_cv_hash.size} #{pid} controlled values from the database." }
      value_cv_hash
    end

    def fetch_descendants(cv, value_cv_hash, dbh=nil)
      if dbh.nil? then
        return @executor.execute { |dbh| fetch_descendants(cv, value_cv_hash, dbh) }
      end
      pid = cv.public_id
      children = []
      dbh.select_all(CHILDREN_STMT, cv.identifier) do |row|
         identifier, value = row
         children << value_cv_hash[value] = make_controlled_value(:identifier => identifier, :public_id => pid, :parent => cv, :value => value)
      end
      # recurse to chidren
      children.each { |cv| fetch_descendants(cv, value_cv_hash, dbh) }
    end
    
    # Returns a new ControlledValue with attributes set by the given attribute => value hash.
    def make_controlled_value(value_hash)
      cv = ControlledValue.new(value_hash[:value], value_hash[:parent])
      cv.identifier = value_hash[:identifier]
      cv.public_id = value_hash[:public_id]
      cv
    end
  end
end