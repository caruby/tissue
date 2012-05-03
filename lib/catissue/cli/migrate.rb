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
        [:input, 'INPUT', 'Source file to migrate'],
        [:target, '-t', '--target CLASS', 'Migration target class'],
        [:mapping, '-m', '--mapping FILE[,FILE...]', Array, 'The input field => caTissue attribute mapping file(s)'],
        [:filters, '--filters FILE[,FILE...]', Array, 'The input value => caTissue value mapping file(s)'],
        [:defaults, '-d', '--defaults FILE[,FILE...]', Array, 'The caTissue attribute default value file(s)'],
        [:shims, '-s', '--shims FILE[,FILE...]', Array, 'Migration customization shim file(s) to load'],
        [:controlled_values, '-k', '--controlled_values', 'Enable controlled value lookup'],
        [:bad, '-b', '--bad FILE', 'Write each invalid record to the given file and continue migration'],
        [:extract, '-x', '--extract FILE', 'Call the migration target extract method to write to the given extract'],
        [:create, '-c', '--create', 'Always create the migration target'],
        [:unique, '-u', '--unique', 'Make the migrated objects unique for testing'],
        [:from, '--from N', Integer, 'Starting input record'],
        [:to, '--to N', Integer, 'Ending input record'],
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
      # the caTissue database.
      #
      # @param opts (see CaTissue::Migrator#initialize)
      # @yield (see CaTissue::Migrator#migrate_to_database)
      # @yieldparam (see CaTissue::Migrator#migrate_to_database)
      def migrate(opts, &block)
        opts[:target] = resolve(opts[:target])
        # Migrate the input.
        CaTissue::Migrator.new(opts).migrate_to_database(&block)
      end
      
      # Resolves the given target class name in the caTissue context.
      #
      # @param [String] name the target class name
      # @return [Class] the resolved class
      # @raise [NameError] if the class could not be resolved
      def resolve(name)
        return if name.nil?
        begin
          # Strip the CaTissue module prefix, if necessary.
          cnm = name.sub(/^CaTissue::/, '')
          # Resolve the class in the CaTissue context.
          CaTissue.module_for_name(cnm)
        rescue Exception => e
          raise NameError.new("Could not load migration target class #{name} - " + $!)
        end
      end
    end
  end
end
