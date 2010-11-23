require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'caruby/util/uniquifier'
require 'test/fixtures/lib/catissue/defaults_test_fixture'

class StorageContainerTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @spc = defaults.specimen
    site = defaults.tissue_bank
    frz_type = CaTissue::StorageType.new(:name => 'Test Freezer'.uniquify, :columns => 1, :rows => 2)
    rack_type = CaTissue::StorageType.new(:name => 'Test Rack'.uniquify, :columns => 2, :rows => 1)
    box_type = CaTissue::StorageType.new(:name => 'Test Box'.uniquify, :columns => 1, :rows => 2)
    array_type = CaTissue::SpecimenArrayType.new(:name => 'SpecimenArray'.uniquify,
      :specimen_class => @spc.specimen_class, :specimen_types => [@spc.specimen_type],
      :columns => 5, :rows => 5)
    frz_type << rack_type
    rack_type << box_type << array_type
    box_type << @spc.specimen_class
    @freezer = CaTissue::StorageContainer.new(:site => site, :container_type => frz_type)
    @array = CaTissue::SpecimenArray.new(:container_type => array_type)
  end

  def test_defaults
    verify_defaults(@freezer)
  end

  def test_add
    @freezer << @spc

    rack = @freezer[0, 0]
    assert_not_nil(rack, "Rack not created")
    assert(@freezer.holds?(rack), "Rack not added to freezer")
    assert_same(@freezer, rack.parent, "Rack parent is not the freezer")
    assert_equal(rack, @freezer[0, 0], "Rack index accessor incorrect")

    box = rack[0, 0]
    assert_not_nil(box, "Box not created")
    assert(rack.holds?(box), "Rack doesn't hold box")
    assert_same(rack, box.parent, "Box parent is not the rack")

    assert(box.holds?(@spc), "Box doesn't hold specimen")
    assert_same(@spc, box[0, 0], "Specimen index accessor incorrect")
    assert_nil(@freezer[0, 1], "Empty slot index accessor not nil")
    assert_nil(@freezer[0, 2], "Column out of bounds index accessor not nil")
    assert_nil(@freezer[1, 0], "Row out of bounds index accessor not nil")
    assert(!rack.full?, "Rack is incorrectly full")
    assert(!box.full?, "Box is incorrectly full")

    # add a new specimen
    @freezer << spc2 =  @spc.copy
    assert_same(box, spc2.position.container, "New specimen box incorrect")
    assert(!rack.full?, "Rack is incorrectly full")
    assert(box.full?, "Box is incorrectly not full")

    # create a new box for another specimen
    @freezer << spc3 = @spc.copy
    assert_not_same(box, spc3.position.container, "New box not allocated")
    assert(rack.full?, "Rack is not full")

    # create a new box for another specimen
    @freezer << spc4 = @spc.copy
    assert_same(spc3.position.container, spc4.position.container, "New box incorrectly allocated")
    
    # fill the freezer
    4.times { @freezer << @spc.copy }
    assert(@freezer.full?, "Freezer incorrectly not full")
    assert(@freezer.completely_full?, "Freezer incorrectly not completely full")
    
    # create a new box with no place to put it
    assert_raises(IndexError, "Add to full box succeeded") { box << @spc.copy }
  end
  
  def test_fill_gap
     @freezer << @spc

    rack = @freezer[0, 0]
    assert_not_nil(rack, "Rack not created")
    box = rack[0, 0]
    assert_not_nil(box, "Box not created")
    
    # make another box
    @freezer << box2 = box.copy(:container_type)
    assert_equal(box2, rack[1, 0], "Rack index accessor incorrect")

    # add a specimen to the second box
    box2 << spc2 = @spc.copy
    assert_equal(spc2, box2[0, 0], "Specimen is placed in #{@spc.position.location} rather than the second box #{box.qp}")
   
    # add a specimen to the first available slot in the first box
    spc3 = @spc.copy
    @freezer << spc3
    assert_equal(spc3, box[0, 1], "Specimen is placed in #{@spc.position.location} rather than the first box #{box.qp}")
    
    # add a specimen to the second box
    @freezer << spc4 = @spc.copy
    assert_equal(spc4, box2[0, 1], "Specimen is not placed in second box")
    
    # fill the freezer
    4.times { @freezer << @spc.copy }
    assert(@freezer.full?, "Freezer incorrectly not full")
    assert(@freezer.completely_full?, "Freezer incorrectly not completely full")
  end

  def test_comparison
    @freezer << @spc
    assert_equal(@freezer, @freezer, "Same not equal")
    rack = @freezer.subcontainers.first
    assert_not_nil(rack, "Rack missing")
    box = rack.subcontainers.first
    assert_not_nil(box, "Box missing")
    assert(rack < @freezer, "Rack not < freezer")
    assert(@freezer > rack, "Freezer not > rack")
    assert(box < rack, "Box not < rack")
    assert(box < @freezer, "Box not < rack")
  end

  def test_save
    @freezer << @spc
    rack = @freezer.subcontainers.first
    assert_not_nil(rack, "Rack missing")
    box = rack.subcontainers.first
    assert_not_nil(box, "Box missing")

    # verify that the box name can be set
    box.name = 'Test Box'.uniquify
    verify_save(box)
    assert_not_nil(@freezer.identifier, "#{@freezer.qp} not saved")

    assert_not_nil(rack.identifier, "#{rack.qp} not saved")
    assert_not_nil(rack.position, "#{rack.qp} position missing")
    assert_not_nil(rack.position.identifier, "#{rack.qp} position not saved")
    assert_not_nil(@freezer.subcontainers.first, "#{@freezer.qp} subcontainer not found")
    assert_same(rack, @freezer.subcontainers.first, "#{@freezer.qp} subcontainer is not the rack")
    assert_same(@freezer, rack.position.parent_container, "#{rack.qp} position container missing")

    assert_not_nil(box.identifier, "#{box} not saved")
    assert_not_nil(box.position, "#{box} position missing")
    assert_not_nil(box.position.identifier, "#{box} position not saved")
    assert_same(rack, box.position.parent_container, "#{box} position container missing")
    assert_not_nil(rack.subcontainers.first, "#{rack.qp} subcontainer not found")
    assert_same(box, rack.subcontainers.first, "#{rack.qp} subcontainer is not the box")

    assert(!box.specimens.empty?, "#{box} doesn't hold a specimen")
    assert_same(@spc, box.specimens.first, "#{box} specimen incorrect")
    assert_not_nil(@spc.identifier, "#{@spc} not saved")
    assert_not_nil(@spc.position, "#{@spc} missing position")
  end
end