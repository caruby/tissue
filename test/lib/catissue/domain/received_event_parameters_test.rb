require File.dirname(__FILE__) + '/../helpers/test_case'
require 'caruby/helpers/validation'

class ReceivedEventParametersTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @scg = defaults.specimen_collection_group
    @spc = defaults.specimen
  end
  
  def test_exclusive_owner_validation
    @spc.collect(:receiver => @scg.receiver)
    rep = @spc.received_event_parameters
    assert_nothing_raised("Owner conflict unexpectedly disallowed") { rep.specimen_collection_group = @scg }
    assert_raises(ValidationError, "Owner conflict allowed") { rep.validate }
  end
end