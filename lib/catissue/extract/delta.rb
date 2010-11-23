require 'date'
require 'caruby/csv/csvio'
require 'caruby/util/log'
require 'caruby/util/collection'
require 'caruby/util/pretty_print'
require 'caruby/database/sql_executor'

module CaTissue
  # Delta determines caTissue objects which changed within a time interval.
  class Delta
    include Enumerable

    private

    SQL_FILE = File.join(File.dirname(__FILE__), '..', '..', '..', 'sql', 'delta.sql')

    public

    # Creates a new Delta for objects of the given target type which changed
    # at or after the since Date and earlier but not at the before Date.
    # The default before Date is now.
    def initialize(target, since, before=nil)
      # convert the required target to a CaTissue class if necessary
      @matcher = create_table_regex(target)
      @since = since
      @before = before || DateTime.now
    end

    # Calls the given block on each caTissue identifier satisfying the delta condition.
    # This method submits the delta SQL and filters the result on the target class.
    # This method always submits the query; the caller is responsible for preserving
    # the result if necessary using {#to_a}.
    def each(&block)
      execute_query(&block)
    end

    private

    # Returns the result of running the delta SQL on the target CaTissue domain class.
    def execute_query
      sql = File.open(SQL_FILE) { |file| file.read }
      logger.debug { "Executing identifier change set selection range #{@since} - #{@before}, SQL:\n#{sql}" }
      CaRuby::SQLExecutor.new(CaTissue.access_properties).execute do |dbh|
        dbh.select_all(sql, @since, @before) do |row|
          table, identifier = row
          yield identifier.to_i if table =~ @matcher
        end
      end
    end

    # Returns the table match REs for the given target class.
    def create_table_regex(target)
      # The class => table RE hash. Make this hash rather than defining a constant in order to enable
      # logging before touching a domain class.
      @cls_tbl_hash ||= {
        CaTissue::Specimen => /catissue_[[:alpha:]]+_specimen/i,
        CaTissue::SpecimenCollectionGroup => /catissue_specimen_coll_group/i
      }
      @cls_tbl_hash.detect_value { |klass, table| table if target <= klass }
    end
  end
end