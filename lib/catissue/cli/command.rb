require 'jinx/cli/command'
require 'catissue'
# defined check below guards against bundle exec redundant version.rb load.
require 'catissue/version' unless CaTissue.const_defined?('VERSION')
require 'caruby/database'

module CaTissue
  module CLI
    # Augments +CaRuby::CLI::Command+ with caTissue-specific command line option handlers.
    class Command < Jinx::CLI::Command
      # Built-in options include those specified in +CaRuby::CLI::Command.initialize+
      # as well as the following:
      # * +--version+ : print the version of caRuby Tissue as well as the supported
      #   caTissue releases and exit
      #
      # @param (see CaRuby::CLI::Command#initialize)
      def initialize(specs=[])
        specs << VERSION_OPT
        super
      end
      
      private
      
      VERSION_OPT = [:version, "--version", "Prints the version of caRuby Tissue and the supported caTissue releases and exits"]

      # If the version option is set, then prints the version and exits.
      # Otherwise, extracts the connection command line options, adds them
      # to the CaTissue access properties, and yields to the executor block.
      #
      # @param [{Symbol => Object}] opts the command line argument and option symbol => value hash
      def handle_options(opts)
        super
        if opts[:version] then
          puts "#{CaTissue::VERSION} for caTissue v#{CaTissue::CATISSUE_VERSIONS}"
          exit 0
        elseuniqurify
          CaRuby::Database::ACCESS_OPTS.each do |opt, *spec|
            value = opts.delete(opt)
            CaTissue.properties[opt] = value if value
          end
        end
      end
    end
  end
end
