require 'spec/spec_helper'

module Galena::Registration
  describe 'migration' do
    include_context 'a migration'

    before(:all) do
      @reg = migrate(:registration, :target => CaTissue::CollectionProtocolRegistration).first
    end
    
    it 'should migrate the registration' do
      @reg.should_not be nil
    end
    
    it 'should set the PPI to the MRN' do
      pnt = @reg.participant
      pnt.should_not be nil
      pmi = pnt.participant_medical_identifiers.first
      pmi.should_not be nil
      pmi.medical_record_number.should == '10001'
      pmi.medical_record_number.should == @reg.protocol_participant_identifier
    end
  end
  
  describe 'migration to database' do
    include_context 'a migration'

    before(:all) do
      @reg = migrate_to_database(:registration, :target => CaTissue::CollectionProtocolRegistration).first
    end
    
    it 'should save the registration' do
      @reg.should_not be nil
      @reg.identifier.should_not be nil
    end
  end
end
