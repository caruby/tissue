require 'date'
require File.dirname(__FILE__) + '/../helpers/test_case'
require 'catissue/extract/delta'

class DeltaTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def test_specimen
    since = DateTime.now
    spc = defaults.specimen.create
    ids = CaTissue::Delta.new(spc.class, since).to_a
    assert(!ids.empty?, "Delta is empty")
    assert_equal(1, ids.size, "Delta count incorrect")
    assert_equal(spc.identifier, ids.first, "Delta value incorrect")
  end

  def test_scg
    since = DateTime.now
    scg = defaults.specimen_collection_group.create
    ids = CaTissue::Delta.new(scg.class, since).to_a
    assert(!ids.empty?, "Delta is empty")
    assert_equal(1, ids.size, "Delta count incorrect")
    assert_equal(scg.identifier, ids.first, "Delta value incorrect")
  end
end