require File.dirname(__FILE__) + '/spec_helper'

module Galena::Annotation
  TARGET = CaTissue::SpecimenCollectionGroup::Pathology::RadicalProstatectomyPathologyAnnotation
  
  describe 'migration' do
    include_context 'a migration'

    before(:all) do
     @pth = migrate(:annotation, :target => TARGET).first
    end

    it 'should save the annotation' do
      @pth.should_not be nil
    end

    it 'should set the comment' do
      @pth.comment.should_not be nil
    end

    it 'should migrate the Gleason score' do
      gls = @pth.gleason_score
      gls.should_not be nil
      gls.primary_pattern_score.should == '3'
    end

    it 'should migrate the grades' do
      grd = @pth.histologic_grades.first
      grd.should_not be nil
      grd.grade.should == '2'
    end
  end
  
  describe 'migration to database' do
    include_context 'a migration'

    before(:all) do
     @pth = migrate_to_database(:annotation, :target => TARGET).first
    end

    it 'should save the annotation' do
      @pth.should_not be nil
      @pth.identifier.should_not be nil
    end
  end
end
