require File.dirname(__FILE__) + '/../../../helpers/test_case'
require 'jinx/helpers/uniquifier'

class SpecimenArrayTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @spc = defaults.specimen
    array_type = CaTissue::SpecimenArrayType.new(:name => 'SpecimenArray'.uniquify, :specimen_class => @spc.specimen_class,
      :specimen_types => [@spc.specimen_type], :columns => 5, :rows => 5)
    @array = CaTissue::SpecimenArray.new(:container_type => array_type)
  end

  def test_defaults
    verify_defaults(@array)
  end
  
  def test_json
    verify_json(@array)
  end
  
  def test_occupied_positions_occlusion
    assert(!CaTissue::SpecimenArray.attributes.include?(:occupied_positions), "occupied_positions is not excluded from SpecimenArray")
    assert(CaTissue::Container.attributes.include?(:occupied_positions), "occupied_positions is not retained in the SpecimenArray superclass")
  end

  def test_can_hold_type
    assert(@array.can_hold_child?(@spc), "Array can't hold specimen type")
    @spc.specimen_type = 'Fixed Tissue'
    assert(!@array.can_hold_child?(@spc), "Array can't hold different specimen type")
  end
  
  def test_add
    assert_raises(NotImplementedError, "Specimen position specimen incorrect") { @array << @spc }
  end

#  def test_save
#    verify_save(@array)
#  end
end
