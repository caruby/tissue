require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'test/fixtures/lib/catissue/defaults_test_fixture'

class SpecimenPositionTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    spc = defaults.specimen
    ctr = defaults.box
    @pos = CaTissue::SpecimenPosition.new(:specimen => spc, :container => ctr, :column => 0, :row => 0)
  end

  def test_defaults
    verify_defaults(@pos)
  end

  def test_inverse_setter
    assert_same(@pos, @pos.specimen.position, "Specimen position not set")
  end

  # Tests creation of {CaTissue::TransferEventParameters} save proxy.
  def test_saver_proxy
    proxy = @pos.saver_proxy
    assert_nil(proxy.from_row, "#{@pos.qp} proxy from row incorrectly set")
    assert_nil(proxy.from_column, "#{@pos.qp} proxy from column incorrectly set")
    assert_equal(@pos.row, proxy.to_row, "#{@pos.qp} proxy to row incorrect")
    assert_equal(@pos.column, proxy.to_column, "#{@pos.qp} proxy to column incorrect")
    
    # simulate move
    @pos.take_snapshot
    @pos.location = @pos.location.succ
    proxy = @pos.saver_proxy
    assert_not_nil(proxy.from_row, "#{@pos.qp} move proxy from row not set")
    assert_equal(@pos.snapshot[:position_dimension_one], proxy.from_position_dimension_one, "#{@pos.qp} move proxy from row incorrect")
    assert_not_nil(proxy.to_row, "#{@pos.qp} move proxy to row not set")
    assert_equal(@pos.snapshot[:position_dimension_two], proxy.from_position_dimension_two, "#{@pos.qp} move proxy from column incorrect")
    assert_equal(@pos.row, proxy.to_row, "#{@pos.qp} proxy to row incorrect")
    assert_equal(@pos.column, proxy.to_column, "#{@pos.qp} proxy to column incorrect")
  end

  def test_save
    spc = @pos.specimen
    verify_save(@pos)
    assert_not_nil(spc.position, "Specimen position missing after position store")
    assert_same(spc, @pos.specimen, "Stored position specimen differs from prior specimen")
    assert_same(@pos, spc.position, "Specimen position differs from stored position")
    # increment the position
    newloc = @pos.location.succ
    spc.move_to(newloc)
    # verify that a specimen update also updates the position
    logger.debug { "Verifying that specimen update reflects the position change..." }
    spc.update
    newpos = spc.position
    assert_not_nil(newpos.identifier, "Specimen update did not save the new position #{newpos}")
    verify_query(newpos.copy(:identifier)) do |result|
      fetched = result.first
      assert_not_nil(fetched, "New position #{newpos} could not be fetched")
      assert_equal(newloc.coordinate, fetched.location.coordinate, "Location not updated")
    end
  end
end