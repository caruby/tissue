require File.join(File.dirname(__FILE__), 'test_case')

module Galena
  module Tissue
    class RegistrationTest < Test::Unit::TestCase
      include MigrationTestCase
    
#      def test_target
#        verify_target(:registration, :target => CaTissue::SpecimenCollectionGroup) do |scg|
#          cpe = scg.collection_event
#          assert_not_nil(cpe, "#{scg} missing CPE")
#          pcl = cpe.protocol
#          assert_not_nil(pcl, "#{scg} CPE #{cpe} missing protocol")
#          assert_not_nil(pcl.short_title, "#{scg} protocol #{pcl} missing short title")
#        end
#      end
    
      def test_save
        verify_save(:registration, :target => CaTissue::SpecimenCollectionGroup)
      end
    end
  end
end
