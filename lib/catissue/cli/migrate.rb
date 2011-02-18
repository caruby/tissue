# the default log file
DEF_LOG_FILE = 'log/migration.log'

require 'catissue/cli/command'
require 'catissue/migration/migrator'

module CaTissue
  module CLI
    class Migrate < Command
      # The migration option specifications.
      #
      # The :unique option ensures that the migrated objects do not conflict with existing or future
      # objects. This is used for testing a migration dry run. It is recommended that the trial run
      # protocol is set to a test protocol as well.
      SPECS = [
        [:input, "-i", "input", "Source file to migrate"],
        [:target, "-t", "--target CLASS", "Migration target class"],
        [:mapping, "-m", "--mapping FILE", "The input field => caTissue attribute mapping file"],
        [:shims, "-s", "--shims FILE[,FILE...]", Array, "Migration customization shim files to load"],
        [:bad, "-b", "--bad FILE", "Write each invalid record to the given file and continue migration"],
        [:unique, "-u", "--unique", "Make the migrated objects unique for testing"],
        [:offset, "-o", "--offset N", Integer, "Number of input records to skip before starting the migration"]
      ]
  
      # Creates a {CaTissue::CLI::Migrate} command with the given standard command line specifications
      # as well as the {SPECS} command line specifications.
      #
      # @param (see CaRuby::CLI::Command#initialize)
      # @yield [opts] optional migrator factory
      # @yieldparam [{Symbol => Object}] the {CaTissue::Migrator#initialize} creation options
      # @see CaRuby::Command#run
      def initialize(&factory)
        super(SPECS) { |opts| migrate(opts, &factory) }
      end
  
      private
      
      # Starts a Migrator with the command-line options.
      #
      # @yield [target] operation on the migration target
      # @yieldparam [CaRuby::Resource] the migrated domain object 
      # @see CaRuby::Command#run
      def migrate(opts)
        validate(opts)
        migrator = block_given? ? yield(opts) : CaTissue::Migrator.new(opts)
        migrator.migrate_to_database
      end
      
      def validate(opts)
        tgt = opts[:target]
        if tgt.nil? then raise ArgumentError.new("Missing required migration target class option") end
        begin
          opts[:target] = CaTissue.const_get(tgt)
        rescue Exception
          logger.fatal("Could not load CaTissue class #{tgt} - #{$!}.\n#{$@.qp}")
          raise MigrationError.new("Could not load migration target class #{tgt}")
        end
      end
    end
  end
end
