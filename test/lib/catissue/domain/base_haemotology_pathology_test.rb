require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'test/fixtures/lib/catissue/defaults_test_fixture'

class BaseHaematologyPathologyTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @scg = defaults.specimen_collection_group
    @annotation = CaTissue::PathologyScg::BaseHaematologyPathologyAnnotation.new(:specimen_collection_group => @scg)
    @histology = CaTissue::PathologyScg::HistologicType.new(:base_pathology_annotation => @annotation, :histologic_type => 'Adenocarcinoma - NOS')
    @finding = CaTissue::PathologyScg::AdditionalFinding.new(:base_pathology_annotation => @annotation, :pathologic_finding => 'Test finding')
    @details = CaTissue::PathologyScg::Details.new(:additional_finding => @finding, :detail => 'Test detail')
  end

  def test_dependents
    assert_equal([@histology], @annotation.histologic_type.to_a, "Annotation histologic types incorrect")
    assert_equal([@finding], @annotation.additional_finding.to_a, "Annotation additional findings incorrect")
    assert_equal([@details], @finding.details.to_a, "Finding details incorrect")
  end

  def test_save
    verify_save(@annotation)
  end
end