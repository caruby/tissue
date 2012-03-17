require File.dirname(__FILE__) + '/spec_helper'

module Galena::General
  describe 'migration' do
    include_context 'a migration'

    before(:all) do
      # The general migration does not have defaults.
      @spc = migrate(:general, :defaults => nil, :target => CaTissue::TissueSpecimen).first
    end
    
    it 'should migrate the specimen' do
      @spc.should_not be nil
    end
    
    it 'should set the specimen type to frozen' do
      @spc.specimen_type.should == 'Frozen Tissue'
    end
    
    it 'should set the quantity' do
      @spc.initial_quantity.should == 3.4
    end
    
    it 'should set the SPN' do
      scg = @spc.specimen_collection_group
      scg.should_not be nil
      scg.surgical_pathology_number.should == '3001'
    end
    
    it 'should set the PPI' do
      reg = @spc.specimen_collection_group.registration
      reg.should_not be nil
      reg.protocol_participant_identifier.should == '301'
    end
    
    it 'should set the participant name' do
      pnt = @spc.specimen_collection_group.registration.participant
      pnt.should_not be nil
      pnt.first_name.should == 'Rufus'
      pnt.last_name.should == 'Firefly'
    end
    
    it 'should set the MRN' do
      pmi = @spc.specimen_collection_group.registration.participant.participant_medical_identifiers.first
      pmi.should_not be nil
      pmi.medical_record_number.should == '30001'
    end
  end
  
  describe 'migration to database' do
    include_context 'a migration'

    before(:all) do
      @spc = migrate_to_database(:general, :defaults => nil, :target => CaTissue::TissueSpecimen).first
    end
    
    it 'should save the specimen' do
      @spc.should_not be nil
      @spc.identifier.should_not be nil
    end
  end
end
