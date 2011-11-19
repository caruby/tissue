require File.dirname(__FILE__) + '/../../helpers/test_case'

class LocationTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    ctr = defaults.box
    ctr.capacity.columns = 1
    ctr.capacity.rows = 2
    @loc = CaTissue::Location.new(:in => ctr, :at => [0, 0])
  end

  def test_equals
    other = CaTissue::Location.new(:in => @loc.container, :at => [@loc.column, @loc.row])
    assert_equal(@loc, other, "Location with equal content not equal")
  end

  def test_successor
    successor = @loc.succ
    assert_not_nil(successor, "Successor location not created")
    assert_not_same(@loc, successor, "Location same as successor")
    assert_same(@loc.container, successor.container, "Location container differs from successor container")
    assert_not_nil(successor.column, "Successor column not set")
    assert_not_nil(successor.row, "Successor row not set")
    assert_equal(0, successor.column, "Successor row incorrect")
    assert_equal(1, successor.row, "Successor column incorrect")
    assert_nil(successor.succ, "Location out of bounds")
  end

  def test_successor_bang
    assert_same(@loc, @loc.succ!, "Location differs from successor bang")
    assert_equal(0, @loc.column, "Successor row incorrect")
    assert_equal(1, @loc.row, "Successor column incorrect")
    assert_raises(IndexError, "Location out of bounds") { @loc.succ! }
  end
end