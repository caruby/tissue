require File.dirname(__FILE__) + '/command'
require 'catissue/migration/migrator'

module CaTissue
  module CLI
    class Migrate < Command
      # The migration option specifications.
      #
      # The +:unique+ option ensures that the migrated objects do not conflict with existing or future
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
        [:offset, "-o", "--offset N", Integer, "Number of input records to skip before starting the migration"],
        [:extract, "--extract EXTRACTOR", "Write the migrated caTissue object to the given appendable object as well as the database"]
      ]

      # Creates a {Migrate} command with the {SPECS} command line specifications
      # as well as the optional specifications parameter.
      #
      # @param (see CaRuby::CLI::Command#initialize)
      # @yield (see #migrate)
      # @yieldparam (see #migrate)
      def initialize(specs=[], &block)
        super(specs.concat(SPECS)) { |opts| migrate(opts, &block) }
      end
  
      private
      
      # Starts a Migrator with the command-line options. Each input record is migrated to
      # the caTissue database. In addition, if the +:extract+ option is set, then each
      # migrated target caTissue domain object is appended to the +:extract+ value using
      # the +<<+ operator. 
      #
      # @param opts (see CaTissue::Migrator#initialize)
      # @yield (see CaTissue::Migrator#migrate_to_database)
      # @yieldparam (see CaTissue::Migrator#migrate_to_database)
      def migrate(opts)
        validate(opts)
        # The extractor which writes a extract from each migrated record.
        @extractor = opts[:extract]
        # Migrate the input.
        CaTissue::Migrator.new(opts).migrate_to_database do |tgt|
          yield tgt if block_given?
          @extractor << tgt if @extractor
        end
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
