require File.join(File.dirname(__FILE__), 'test_case')

module Galena
  module Tissue
    class RegistrationTest < Test::Unit::TestCase
      include MigrationTestCase
    
      def test_target
        verify_target(:registration, :target => CaTissue::SpecimenCollectionGroup)
      end
    
      def test_save
        verify_save(:registration, :target => CaTissue::SpecimenCollectionGroup)
      end
    end
  end
end
