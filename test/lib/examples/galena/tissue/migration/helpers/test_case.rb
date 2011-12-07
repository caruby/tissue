require File.dirname(__FILE__) + '/../../../../../catissue/migration/helpers/test_case'
require File.dirname(__FILE__) + '/../../helpers/test_case'
require File.dirname(__FILE__) + '/seed'

module Galena
  module Tissue
    module MigrationTestCase
      include CaTissue::MigrationTestCase, TestCase
    
      def setup
        super(FIXTURES)
      end
      
      private
      
      # The migration input data directory.
      FIXTURES = File.dirname(__FILE__) + '/../../../../examples/galena/data'
    end
  end
end
