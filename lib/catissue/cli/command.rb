# the standard log file
DEF_LOG_FILE = 'log/catissue.log' unless defined?(DEF_LOG_FILE)

begin
  require 'catissue'
rescue Exception => e
  logger.error("caTissue client load was unsuccessful - #{e}:\n#{e.backtrace.qp}")
  puts "caTissue client load was unsuccessful - #{e}."
  puts "See the log at #{CaRuby::Log.instance.file} for more information."
  exit 1
end

require 'caruby/cli/command'
require 'catissue/version'

module CaTissue
  module CLI
    # Augments {CaRuby::CLI::Command} with caTissue-specific command line option handlers.
    class Command < CaRuby::CLI::Command
<<<<<<< HEAD
      # 
      # Built-in options include those specified in +CaRuby::CLI::Command.initialize+
      # as well as the following:
      # * --version : print the version of caRuby Tissue as well as the supported caTissue releases and exit
      #
      # @param [(<Symbol>, <String, Class>)] specs the arguments and options
      #   described in +CaRuby::CLI::Command.initialize+
=======
      # @see {CaRuby::CLI::Command#initialize}
>>>>>>> parent of 745f9e3... Clean up documentation.
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
          CaRuby::ACCESS_OPTS.each do |opt, *spec|
            value = opts.delete(opt)
            CaTissue.access_properties[opt] = value if value
          end
        end
      end
    end
  end
end
