require 'date'
require 'caruby/csv/csvio'
require 'caruby/util/log'
require 'caruby/util/collection'
require 'caruby/util/pretty_print'
require 'catissue/database'

module CaTissue
  # Delta determines caTissue objects which changed within a time interval.
  class Delta
    include Enumerable

    # Initializes this delta for objects of the given target type which changed
    # at or after the since date and earlier than the before date.
    #
    # @param [Class] target the type for which the delta is determined
    # @param [Date] since the delta start time
    # @param [Date, nil] since the delta end time (default now)
    def initialize(target, since, before=nil)
      # convert the required target to a CaTissue class if necessary
      @matcher = create_table_regex(target)
      @since = since
      @before = before || DateTime.now
    end

    # Calls the given block on each caTissue identifier satisfying the delta condition.
    # This method submits the delta SQL and filters the result on the target class.
    # This method always submits the query; the caller is responsible for capturing
    # the result if necessary for a subsequent iteration.
    #
    # @yield [identifier] filters the Resources changed in the delta window
    # @yieldparam [Integer] identifier the Resource database id
    def each(&block)
      execute_query(&block)
    end

    private

    # The parameterized SQL for determining
    SQL_FILE = File.join(File.dirname(__FILE__), '..', '..', '..', 'sql', 'delta.sql')

    # @return [<Resource>] the result of running the delta SQL on the target CaTissue domain class
    def execute_query
      sql = File.open(SQL_FILE) { |file| file.read }
      logger.debug { "Executing identifier change set selection range #{@since} - #{@before}, SQL:\n#{sql}" }
      CaTissue::Database.executor.execute do |dbh|
        dbh.select_all(sql, @since, @before) do |row|
          table, identifier = row
          yield identifier.to_i if table =~ @matcher
        end
      end
    end

    # @param [Class] the target domain class
    # @return [RegularExpression, nil] the table match RE for the given target class, if any
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