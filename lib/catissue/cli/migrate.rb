require File.dirname(__FILE__) + '/command'
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
        [:input, "input", "Source file to migrate"],
        [:target, "-t", "--target CLASS", "Migration target class"],
        [:mapping, "-m", "--mapping FILE[,FILE...]", Array, "The input field => caTissue attribute mapping file(s)"],
        [:filters, "--filters FILE[,FILE...]", Array, "The input value => caTissue value mapping file(s)"],
        [:defaults, "-d", "--defaults FILE[,FILE...]", Array, "The caTissue attribute default value file(s)"],
        [:shims, "-s", "--shims FILE[,FILE...]", Array, "Migration customization shim file(s) to load"],
        [:bad, "-b", "--bad FILE", "Write each invalid record to the given file and continue migration"],
        [:unique, "-u", "--unique", "Make the migrated objects unique for testing"],
        [:offset, "-o", "--offset N", Integer, "Number of input records to skip before starting the migration"]
      ]
  
      # Creates a {Migrate} command with the given standard command line specifications
      # as well as the {SPECS} command line specifications.
      #
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
    end
  end
end
