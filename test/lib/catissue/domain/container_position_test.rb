require File.dirname(__FILE__) + '/../../../helpers/test_case'

class SpecimenPositionTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    site = defaults.tissue_bank
    frz_type = CaTissue::StorageType.new(:name => Jinx::StringUniquifier.uniquify('Freezer'), :columns => 2, :rows => 1)
    rack_type = CaTissue::StorageType.new(:name => Jinx::StringUniquifier.uniquify('Rack'), :columns => 1, :rows => 2)
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

  # Passes in caTissue 1.1.2, but fails in caTissue 1.2, which does not allow updating
  # a container position.
  # TODO - why is a position updated?
  # def test_save
  #   verify_save(@pos)
  # end
end