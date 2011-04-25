require File.join(File.dirname(__FILE__), 'test_case')

# Tests the Galena example migration.
module Galena
  module Tissue
    class SimpleTest < Test::Unit::TestCase
      include MigrationTestCase
    
      def test_target
        verify_target(:simple) do |spc|
          assert_not_nil(spc.initial_quantity, "Missing quantity")
          scg = spc.specimen_collection_group
          assert_not_nil(scg, "Missing SCG")
          pnt = scg.registration.participant
          assert_not_nil(pnt, "Missing Participant")
          pmi = pnt.participant_medical_identifiers.first
          assert_not_nil(pmi, "Missing PMI")
          mrn = pmi.medical_record_number
          assert_not_nil(mrn, "Missing MRN")
          rep = spc.received_event_parameters
          assert_not_nil(rep, "Missing REP")
          assert_not_nil(rep.timestamp, "Missing received date")
        end
      end
    
      def test_save
        verify_save(:simple)
      end
    end
  end
end
