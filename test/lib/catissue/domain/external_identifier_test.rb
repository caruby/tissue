require File.dirname(__FILE__) + '/../../../helpers/test_case'

class ExternalIdentifierTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @spc = defaults.specimen
    @eid = CaTissue::ExternalIdentifier.new(
      :name => Jinx::Uniquifier.instance.uniquify('Test Name'),
      :value => Jinx::Uniquifier.instance.uniquify('Test Value'),
      :specimen => @spc
    )
  end

  def test_defaults
    verify_defaults(@eid)
  end

  # Exercises the CaTissue::Specimen external_identifiers logical dependency work-around.
  def test_save
    # create the EID
    verify_save(@eid)
    # update the EID
    oldval = @eid.value
    newval = @eid.value = Jinx::Uniquifier.instance.uniquify('Test Value')
    logger.debug { "#{self} verifying #{@eid} update of value from #{oldval} to #{newval}..." }
    verify_save(@eid)
  end
end