require File.dirname(__FILE__) + '/spec_helper'

module Galena::Frozen
  describe 'migration' do
    include_context 'a migration'

    before(:all) do
      @spc = migrate(:frozen, :target => CaTissue::TissueSpecimen).first
    end
    
    it 'should migrate the specimen' do
      @spc.should_not be nil
    end
    
    it 'should set the specimen type to frozen' do
      @spc.specimen_type.should == 'Frozen Tissue'
    end
    
    it 'should store the specimen' do
      pos = @spc.position
      pos.should_not be nil
      pos.holder.should_not be nil
      pos.occupant.should be @spc
    end
  end
  
  describe 'migration to database' do
    include_context 'a migration'

    before(:all) do
      @spc = migrate_to_database(:frozen, :target => CaTissue::TissueSpecimen).first
    end
    
    it 'should save the specimen' do
      @spc.should_not be nil
      @spc.identifier.should_not be nil
    end
  end
end
