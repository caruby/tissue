require File.dirname(__FILE__) + '/../../../helpers/test_case'

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
  
  def test_match
    other = @xfr.copy
    assert(!@xfr.matches?(other), "#{other} incorrectly matches #{@xfr}")
  end

  def test_inverse_setter
    assert(@xfr.specimen.specimen_event_parameters.include?(@xfr), "#{@xfr} not found in specimen")
  end

  def test_move
    prev = @xfr.to
    @xfr.to = prev.succ
    assert_equal(prev.column + 1, @xfr.to.column, "#{@xfr} position not incremented")
  end

  def test_save
    logger.debug { "#{self} testing #{@xfr.specimen} storage at #{@xfr.to.coordinate.qp}." }
    verify_save(@xfr)
    moved = CaTissue::TransferEventParameters.new(:specimen => @xfr.specimen, :from => @xfr.to, :to => @xfr.to.succ)
    logger.debug { "#{self} testing #{@xfr.specimen} move from #{moved.from.coordinate.qp} to #{moved.to.coordinate.qp}." }
    verify_save(moved)
  end
end