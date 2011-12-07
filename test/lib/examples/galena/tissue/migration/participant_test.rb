require File.dirname(__FILE__) + '/helpers/test_case'

module Galena
  module Tissue
    class ParticipantMigrationTest < Test::Unit::TestCase
      include MigrationTestCase
    
      def test_target
        verify_target(:participant, :target => CaTissue::Participant)
      end
    
      def test_save
        clear
        # test the create
        verify_save(:participant, :target => CaTissue::Participant)
      end
      
      def test_create
        clear
        # make the test participant
        pnt = CaTissue::Participant.new(:social_security_number => '333-66-9999')
        pnt.create
        migrate_to_database(:participant, :target => CaTissue::Participant, :create=>true)
        # Verify that the name was not updated.
        pnt.identifier = nil
        pnt.find
        assert_nil(pnt.last_name, "Existing participant was updated despite the migration :create flag")
      end
      
      private
      
      ALT_ID_SHIM = File.expand_path('alt_key.rb', File.dirname(__FILE__) + '/helpers')
      
      def clear
        # push aside the existing test participant
        pnt = CaTissue::Participant.new(:social_security_number => '333-66-9999')
        if pnt.find then
          pnt.social_security_number = nil
          pnt.update
        end
      end
    end
  end
end
