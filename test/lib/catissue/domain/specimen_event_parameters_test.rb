require File.dirname(__FILE__) + '/../../../helpers/test_case'

class SpecimenEventParametersTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    specimen = defaults.specimen
    @sep = CaTissue::Collectible.create_parameters(:frozen, specimen, :user => specimen.specimen_collection_group.receiver, :freeze_method => 'Cryobath')
  end

  def test_defaults
    verify_defaults(@sep)
  end

  def test_missing_scg
    @sep.specimen_collection_group = nil
    assert_raises(Jinx::ValidationError, "Parameters without SCG passes SCG validation") { @sep.validate }
  end

  def test_java_date
    @sep.timestamp = now = Java.now
    verify_defaults(@sep)
    assert_equal(now.to_ruby_date.to_s, @sep.timestamp.to_s, "Java timestamp incorrect")
  end

  def test_ruby_date
    @sep.timestamp = now = DateTime.now
    verify_defaults(@sep)
    assert_equal(now.to_s, @sep.timestamp.to_s, "Ruby timestamp incorrect")
  end

  def test_owner
    assert_same(@sep.specimen, @sep.owner, "Specimen SEP owner incorrect")
  end
  
  ## DATABASE TESTS ##

  def test_save_specimen_sep
    verify_save(@sep)
    # update the freeze method
    @sep.freeze_method = 'Cryostat'
    logger.debug { "#{self.class.qp} updating #{@sep.qp}..." }
    verify_save(@sep)
  end
end