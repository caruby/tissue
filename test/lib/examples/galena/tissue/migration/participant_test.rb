require File.join(File.dirname(__FILE__), 'test_case')

# Tests the Galena example migration.
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
      
      def test_create_with_alternate_id
        clear
        # make the test participant
        pnt = CaTissue::Participant.new(:first_name => 'Rufus', :last_name => 'Firefly')
        # move aside duplicates
        pnt.query.each do |dup|
          dup.last_name = dup.last_name.uniquify
          dup.save
        end
        pnt.create
        migrate_to_database(:participant, :target => CaTissue::Participant, :shims => [ALT_ID_SHIM], :create=>true)
        # Verify that the SSN was not updated.
        pnt.identifier = nil
        pnt.find
        assert_nil(pnt.social_security_number, "Existing participant with alternate key was updated despite the migration :create flag")
      end
      
      private
      
      ALT_ID_SHIM = 'test/fixtures/lib/examples/galena/migration/alt_key_shims.rb'
      
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
