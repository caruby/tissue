require File.join(File.dirname(__FILE__), 'test_case')

# Tests the Galena example migration.
module Galena
  module Tissue
    class AnnotationTest < Test::Unit::TestCase
      include MigrationTestCase
    
      def test_target
        verify_target(:annotation) do |spc|
          assert_not_nil(spc.initial_quantity, "Missing quantity")
          pth = spc.pathology.prostate_specimen_pathology_annotations.first
          assert_not_nil(pth, "Missing #{spc} annotation")
          assert_not_nil(pth.comments, "Missing #{pth} comments")
          gls = pth.gleason_score
          assert_not_nil(pth, "Missing #{pth} gleason score")
          assert_equal(3, gls.primary_pattern_score, "Gleason score incorrect")
          grd = pth.histologic_grades.first
          assert_not_nil(grd, "Missing #{pth} grade")
          assert_equal('2', grd.grade, "Grade incorrect")
        end
      end
    
      def test_save
        verify_save(:annotation)
      end
    end
  end
end
