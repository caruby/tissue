require File.dirname(__FILE__) + '/../helpers/test_case'
require 'caruby/util/uniquifier'

class StorageTypeTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @spc = defaults.specimen
    @frz_type = CaTissue::StorageType.new(:name => 'Freezer'.uniquify, :columns => 5, :rows => 5)
    @rack_type = CaTissue::StorageType.new(:name => 'Rack'.uniquify, :columns => 1, :rows => 1)
    @box_type = CaTissue::StorageType.new(:name => 'Box'.uniquify, :columns => 1, :rows => 1)
    @array_type = CaTissue::SpecimenArrayType.new(:name => 'SpecimenArray'.uniquify,
      :specimen_class => @spc.specimen_class, :specimen_types => [@spc.specimen_type],
      :columns => 5, :rows => 5)
    @frz_type << @rack_type
    @rack_type << @box_type
    @box_type << @array_type << @spc.specimen_class
  end

  def test_defaults
    verify_defaults(@frz_type)
  end

  def test_new_container
    frz = @frz_type.new_container
    assert_same(CaTissue::StorageContainer, frz.class, "Created instance class incorrect")
    assert_same(@frz_type, frz.container_type, "Created container type incorrect")
  end

  def test_can_hold
    assert(@frz_type.can_hold_child?(@rack_type.new_container), "Freezer can't hold a rack")
    assert(@rack_type.can_hold_child?(@box_type.new_container), "Rack can't hold a box")
    assert(@box_type.can_hold_child?(@array_type.new_container), "Box can't hold an array")
    assert(@array_type.can_hold_child?(@spc), "Array can't hold the specimen")
    assert(@box_type.can_hold_child?(@spc), "Box can't hold the specimen")
  end

  def test_comparison
    assert_equal(@frz_type, @frz_type, "Same not equal")
    assert_equal(@frz_type, @frz_type.copy(:name), "Name not used in equality")
    assert(@rack_type < @frz_type, "Rack type not < freezer type")
    assert(@frz_type > @rack_type, "Freezer type not > rack type")
    assert(@box_type < @rack_type, "Box type not < rack type")
  end
  
  def test_closure
    assert_equal([@frz_type, @rack_type, @box_type], @frz_type.closure,  "Freezer type closure incorrect")
  end

  def test_path_to
    assert_equal([@frz_type, @rack_type, @box_type], @frz_type.path_to(@spc), "Freezer path to specimen incorrect")
  end
  
  ## DATABASE TESTS ##

  def test_save
    verify_save(@box_type)
    assert(@box_type.find_containers.empty?, "Box incorrectly found")
    site = defaults.tissue_bank
    box = @box_type.find_available(site)
    assert_nil(box, "Available box incorrectly created")
    box = @box_type.find_available(site, :create)
    assert_not_nil(box, "Available box not created")
    assert_not_nil(box.identifier, "Available box missing identifier")
    stored = @box_type.find_containers.map { |ctr| ctr.identifier}
    assert_equal([box.identifier], stored, "Box with identifier #{box.identifier} not found")
  end
end