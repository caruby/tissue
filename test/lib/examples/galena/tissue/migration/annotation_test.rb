require File.dirname(__FILE__) + '/helpers/test_case'

module Galena
  module Tissue
    class AnnotationTest < Test::Unit::TestCase
      include MigrationTestCase
    
      def test_target
        verify_target(:annotation, :target => CaTissue::SpecimenCollectionGroup) do |scg|
          pth = scg.pathology.first
          assert_not_nil(pth, "Missing #{scg} pathology annotation proxy")
          pst = pth.radical_prostatectomy_pathology_annotations.first
          assert_not_nil(pst, "Missing #{scg} prostate annotation")
          assert_not_nil(pst.comment, "Missing #{pst} comments")
          gls = pst.gleason_score
          assert_not_nil(pst, "Missing #{pst} gleason score")
          assert_equal('3', gls.primary_pattern_score, "Gleason score incorrect")
          grd = pst.histologic_grades.first
          assert_not_nil(grd, "Missing #{pst} grade")
          assert_equal('2', grd.grade, "Grade incorrect")
        end
      end
    
      def test_save
        verify_save(:annotation, :target => CaTissue::SpecimenCollectionGroup)
      end
    end
  end
end
