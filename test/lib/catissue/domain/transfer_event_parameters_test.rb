require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'test/fixtures/lib/catissue/defaults_test_fixture'
require 'caruby/database/store_template_builder'

class TransferEventParametersTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    spc = defaults.specimen
    defaults.box << spc
    @xfr = CaTissue::TransferEventParameters.new(:specimen => spc, :to => spc.location)
  end

#  def test_inverse_setter
#    assert(@xfr.specimen.event_parameters.include?(@xfr), "EventParameters not found in specimen")
#  end
#
#  def test_defaults
#    verify_defaults(@xfr)
#  end

#  def test_save
#    verify_save(@xfr)
#    shift(@xfr)
#    verify_save(@xfr)
#  end

  private

  # Resets the given CaTissue::TransferEventParameters xfr so that +from+ is the
  # old +to+, +to+ is the next location, and the identifier is cleared.
  def shift(xfr)
    xfr.from = xfr.to
    xfr.to = xfr.from.succ
    xfr.identifier = nil
  end
end