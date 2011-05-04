require File.join(File.dirname(__FILE__), 'test_case')

module Galena
  module Tissue
    class AnnotationTest < Test::Unit::TestCase
      include MigrationTestCase
    
      def test_target
        verify_target(:annotation, :target => CaTissue::SpecimenCollectionGroup) do |scg|
          pth = scg.pathology.radical_prostatectomy_pathology_annotations.first
          assert_not_nil(pth, "Missing #{scg} annotation")
          assert_not_nil(pth.comment, "Missing #{pth} comments")
          gls = pth.gleason_score
          assert_not_nil(pth, "Missing #{pth} gleason score")
          assert_equal('3', gls.primary_pattern_score, "Gleason score incorrect")
          grd = pth.histologic_grades.first
          assert_not_nil(grd, "Missing #{pth} grade")
          assert_equal('2', grd.grade, "Grade incorrect")
        end
      end
    
      def test_save
        verify_save(:annotation, :target => CaTissue::SpecimenCollectionGroup)
      end
    end
  end
end
