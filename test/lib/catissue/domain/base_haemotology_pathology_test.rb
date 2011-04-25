require File.join(File.dirname(__FILE__), '..', 'test_case')

class BaseHaematologyPathologyTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @scg = defaults.specimen_collection_group
    @ann = CaTissue::SpecimenCollectionGroup::Pathology::BaseHaematologyPathologyAnnotation.new(:specimen_collection_group => @scg)
    @hist = CaTissue::SpecimenCollectionGroup::Pathology::HistologicType.new(:base_pathology_annotation => @ann, :histologic_type => 'Adenocarcinoma - NOS')
    @fnd = CaTissue::SpecimenCollectionGroup::Pathology::AdditionalFinding.new(:base_pathology_annotation => @ann, :pathologic_finding => 'Test finding')
    @dtl = CaTissue::SpecimenCollectionGroup::Pathology::Details.new(:additional_finding => @fnd, :detail => 'Test detail')
  end

  def test_dependents
    assert_equal([@hist], @ann.histologic_types.to_a, "Annotation histologic types incorrect")
    assert_equal([@fnd], @ann.additional_findings.to_a, "Annotation additional findings incorrect")
    assert_equal([@dtl], @fnd.details.to_a, "Finding details incorrect")
  end

  def test_save
    verify_save(@ann)
  end
end