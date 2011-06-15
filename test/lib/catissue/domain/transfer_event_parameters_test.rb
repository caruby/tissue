require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'caruby/database/store_template_builder'

class TransferEventParametersTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    spc = defaults.specimen
    defaults.box << spc
    @xfr = CaTissue::TransferEventParameters.new(:specimen => spc, :to => spc.location)
  end

  def test_defaults
    verify_defaults(@xfr)
  end

  def test_inverse_setter
    assert(@xfr.specimen.event_parameters.include?(@xfr), "EventParameters not found in specimen")
  end

  def test_save
    logger.debug { "#{self} testing #{xfr.specimen} storage at #{xfr.to.coordinate.qp}." }
    verify_save(@xfr)
    shift(@xfr)
    logger.debug { "#{self} testing #{xfr.specimen} move from #{xfr.from.coordinate.qp} to #{xfr.to.coordinate.qp}." }
    verify_save(@xfr)
  end

  private

  # Resets the given CaTissue::TransferEventParameters xfr so that +from+ is the
  # old +to+, +to+ is the next location, and the identifier is cleared.
  def shift(xfr)
    xfr.from = xfr.to
    xfr.to = xfr.from.succ
    xfr.identifier = nil
  end
end