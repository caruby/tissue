require File.dirname(__FILE__) + '/spec_helper'

module Galena::Simple
  describe 'migration' do
    include_context 'a migration'

    before(:all) do
      @spc = migrate(:simple, :target => CaTissue::TissueSpecimen).first
    end
    
    it 'should save the specimen' do
      @spc.should_not be nil
    end

    it 'should set the quantity' do
      @spc.initial_quantity.should == 3.0
    end

    it 'should reference a SCG which includes the specimen' do
      scg = @spc.specimen_collection_group
      scg.should_not be nil
      scg.specimens.size.should be 1
      scg.specimens.first.should be @spc
    end

    it 'should register a participant with last name the same as the MRN' do
      reg = @spc.specimen_collection_group.registration
      reg.should_not be nil
      pnt = reg.participant
      pnt.should_not be nil
      pnt.participant_medical_identifiers.size.should be 1
      pmi = pnt.participant_medical_identifiers.first
      pmi.medical_record_number.should == '20001'
      pnt.last_name.should == pmi.medical_record_number
    end

    it 'should set the received date' do
      rep = @spc.received_event_parameters
      rep.should_not be nil
      rep.timestamp.year.should == 2007
      rep.timestamp.month.should == 12
      rep.timestamp.day.should == 4
    end
  end
  
  describe 'migration to database' do
    include_context 'a migration'

    before(:all) do
      @spc = migrate_to_database(:simple, :target => CaTissue::TissueSpecimen).first
    end
    
    it 'should save the specimen' do
      @spc.should_not be nil
      @spc.identifier.should_not be nil
    end
  end
end
