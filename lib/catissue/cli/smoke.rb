require 'catissue/cli/command'
require 'catissue/database'

module CaTissue
  module CLI
    class Smoke < Command
      # Creates a new Smoke command.
      def initialize
        super { |opts| execute }
      end
      
      private
      
      DB_MSG = "Verifying database access by searching for the pre-defined #{CaTissue::Site::DEF_SITE_NAME} Site..."
      
      # Runs the smoke test.
      def execute
        puts DB_MSG
        logger.info(DB_MSG)
        # connect to the database and query on a Site
        CaTissue::Database.instance.open { find_in_transit_site }
      end
      
      def find_in_transit_site
        begin
          site = CaTissue::Site.new(:name => CaTissue::Site::DEF_SITE_NAME).find
        rescue Exception => e
          logger.error("caTissue database access was unsuccessful - #{e}:\n#{e.backtrace.qp}")
          puts "caTissue database access was unsuccessful - #{e}."
          puts "See the log at #{DEF_LOG_FILE} for more information."
        end
        
        if site then
          puts "The #{CaTissue::Site::DEF_SITE_NAME} Site was found with identifier #{site.identifier}."
          puts "Smoke test successful."
          exit 0
        else
          puts "The #{CaTissue::Site::DEF_SITE_NAME} Site was not found."
          puts "Smoke test unsuccessful."
          exit 69 # service unavailable error status
        end
      end
    end
  end
end