require 'rubygems'
require 'bundler/setup'

require 'catissue'
require 'caruby/cli/command'
require 'caruby/database'

module CaTissue
  module CLI
    # Augments +CaRuby::CLI::Command+ with caTissue-specific command line option handlers.
    class Command < CaRuby::CLI::Command
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
        else
          CaRuby::Database::ACCESS_OPTS.each do |opt, *spec|
            value = opts.delete(opt)
            CaTissue.properties[opt] = value if value
          end
        end
      end
    end
  end
end
