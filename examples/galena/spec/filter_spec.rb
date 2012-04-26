require 'spec/spec_helper'
require 'fileutils'

module Galena::Filter
  RESULTS = File.dirname(__FILE__) + '/../results'
  
  # The rejects file.
  REJECTS = RESULTS + '/filter/rejects.csv'
  
  # The migration options.
  OPTS = {:target => CaTissue::TissueSpecimen, :bad => REJECTS}
  
  describe 'migration' do
    include_context 'a migration'

    before(:all) do
      FileUtils.rm_rf RESULTS
      @spcs = migrate(:filter, OPTS)
    end
    
    after(:all) do
      FileUtils.rm_rf RESULTS
    end
    
    it 'should migrate the valid specimens' do
      @spcs.size.should be 3
    end
    
    it 'should reject the invalid specimens' do
      File.readlines(REJECTS).to_a.size.should be 1
    end
      
    it 'should infer the fixed specimen' do
      @spcs.select { |spc| spc.specimen_type == 'Fixed Tissue' }.size.should be 1
    end
    
    it 'should infer the frozen specimens' do
      @spcs.select { |spc| spc.specimen_type == 'Frozen Tissue' }.size.should be 2
    end
    
    context 'specimen' do
      subject { @spcs.first }

      it 'should set the quantity' do
        subject.initial_quantity.should == 3.4
      end

      it 'should reference a SCG with a SPN' do
        scg = subject.specimen_collection_group
        scg.should_not be nil
        scg.surgical_pathology_number.should == '4001'
      end

      it 'should register a participant with the name given by the parsed initials' do
        reg = subject.specimen_collection_group.registration
        reg.should_not be nil
        pnt = reg.participant
        pnt.should_not be nil
        pnt.first_name.should == 'U'
        pnt.last_name.should == 'Z'
      end

      it 'should set the received date' do
        rep = subject.received_event_parameters
        rep.should_not be nil
        rep.timestamp.year.should == 2007
        rep.timestamp.month.should == 1
        rep.timestamp.day.should == 4
      end
    end
  end
  
  describe 'migration to database' do
    include_context 'a migration'

    before(:all) do
      FileUtils.rm_rf RESULTS
      @spcs = migrate_to_database(:filter, OPTS)
    end
    
    after(:all) do
      FileUtils.rm_rf RESULTS
    end
    
    it 'should save the valid specimens' do
      @spcs.size.should be 3
      @spcs.each { |spc| spc.identifier.should_not be nil }
    end
    
    it 'should reject the invalid specimens' do
      File.readlines(REJECTS).size.should be 1
    end
  end
end
