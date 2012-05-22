require File.dirname(__FILE__) + '/../../../helpers/test_case'

class SpecimenRequirementTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @rqmt = defaults.specimen_requirement
  end

  def test_event
    assert(@rqmt.collection_event.requirements.include?(@rqmt), "Event requirements not updated")
  end

  def test_defaults
    @rqmt.specimen_characteristics = nil
    verify_defaults(@rqmt)
  end
  
  def test_json
    verify_json(@rqmt)
  end

  # Tests whether the child_specimens domain type is overridden in the configuration from the
  # inferred Java parameterized generic type property.
  def test_child_specimens_type
    msg = "The #{@rqmt} child_specimens property type was not reset to the non-abstract SpecimenRequirement"
    assert_equal(CaTissue::SpecimenRequirement, @rqmt.class.domain_type(:child_specimens), msg)
  end
  
  def test_derivative_validation
    @rqmt.derive(:count => 2, :specimen_type => (@rqmt.specimen_type + ' Block'))
    assert_equal(2, @rqmt.children.size, "Derived requirement count incorrect")
    @rqmt.add_defaults
    assert_raise(Jinx::ValidationError, "Multiple derivatives incorrectly succeeds validation") { @rqmt.validate }
  end
  
  def test_save
    verify_save(@rqmt)
    # query the CPE
    cpe = @rqmt.collection_protocol_event
    tmpl = CaTissue::SpecimenRequirement.new(:collection_protocol_event => cpe)
    logger.debug { "Verifying the Requirement CPE query #{tmpl.qp}..." }
    verify_query(tmpl) do |result|
      assert_equal(1, result.size, "Requirement event query result size incorrect")
      assert_equal(@rqmt.identifier, result.first.identifier, "Requirement event query result identifier incorrect")
    end
  end
  
  def test_derived_store
    child = @rqmt.derive
    verify_save(@rqmt)
    assert_equal(1, @rqmt.children.size, "Requirment children size incorrect")
    assert_same(child, @rqmt.children.first, "Requirment child incorrect")
  
    # query the derived Requirement
    tmpl = child.class.new(:parent => @rqmt.copy(:identifier))
    logger.debug { "Verifying the derived Requirement query #{tmpl}..." }
    verify_query(tmpl) do |result|
      assert_equal(1, result.size, "Derived requirement query result size incorrect")
      assert_equal(child.identifier, result.first.identifier, "Derived requirement query result identifier incorrect")
    end
  end
end
