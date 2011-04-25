require File.join(File.dirname(__FILE__), '..', 'test_case')

class SpecimenPositionTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    site = defaults.tissue_bank
    frz_type = CaTissue::StorageType.new(:name => 'Freezer'.uniquify, :columns => 2, :rows => 1)
    rack_type = CaTissue::StorageType.new(:name => 'Rack'.uniquify, :columns => 1, :rows => 2)
    frz_type << rack_type
    freezer = CaTissue::StorageContainer.new(:site => site, :container_type => frz_type)
    rack = CaTissue::StorageContainer.new(:site => site, :container_type => rack_type)
    @pos = CaTissue::ContainerPosition.new(:holder => freezer, :occupant => rack, :column => 0, :row => 0)
  end

  def test_defaults
    verify_defaults(@pos)
  end

  def test_inverse_setter
    assert_same(@pos, @pos.occupant.position, "Container position not set")
  end

  def test_save
    verify_save(@pos)
  end
end