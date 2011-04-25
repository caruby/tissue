require File.join(File.dirname(__FILE__), 'test_case')

module Galena
  module Tissue
    class GeneralMigrationTest < Test::Unit::TestCase
      include Galena::Tissue::MigrationTestCase
    
      def test_target
        verify_target(:general) do |spc|
          assert_not_nil(spc.initial_quantity, "Missing quantity")
          scg = spc.specimen_collection_group
          assert_not_nil(scg, "Missing SCG")
          pnt = scg.registration.participant
          assert_not_nil(pnt, "Missing Participant")
          pmi = pnt.participant_medical_identifiers.first
          assert_not_nil(pmi, "Missing PMI")
          mrn = pmi.medical_record_number
          assert_not_nil(mrn, "Missing MRN")
          rep = scg.received_event_parameters
          assert_not_nil(rep, "Missing REP")
          assert_not_nil(rep.timestamp, "Missing received date")
        end
      end
     
      def test_save
        # Clear a space for the specimen
        box = CaTissue::StorageContainer.new(:name => 'GTB Box 1')
        if box.find then
          box.name = box.name.uniquify
          box.save
        end
        
        # Make the surgeon user, if necessary, by copying the required attributes from the coordinator.
        crd = defaults.tissue_bank.coordinator
        srg = defaults.tissue_bank.coordinator.copy(:cancer_research_group, :department, :institution)
        srg.address = crd.address.copy
        srg.email_address = 'serge.on@galena.edu'
        srg.first_name = 'Serge'
        srg.last_name = 'On'
        srg.find(:create)
    
        # migrate the Specimen input record
        verify_save(:general) do |spc|
          logger.debug { "Verifying saved #{spc}..." }
          assert_equal('Frozen Tissue', spc.specimen_type, "#{spc} specimen type incorrect")
          scg = spc.specimen_collection_group
          assert_not_nil(scg, "#{spc} missing SCG")
          assert_equal('Complete', scg.collection_status, "#{scg} collection status incorrect")
          spcs = scg.specimens
          assert_equal(1, spcs.size, "#{scg} specimen count incorrect")
          assert_same(spc, spcs.first, "#{scg} specimen incorrect")
       end
     end
   end
  end
end
