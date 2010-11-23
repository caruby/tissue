require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'caruby/util/uniquifier'

class SpecimenArrayTypeTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @type = CaTissue::SpecimenArrayType.new(:name => 'SpecimenArrayType'.uniquify,
      :specimen_class => 'Frozen Tissue', :columns => 5,  :rows => 5)
    @type.specimen_types << 'Tissue'
  end

  def test_defaults
    verify_defaults(@type)
  end

  def test_create
    array = @type.create
    assert_same(CaTissue::SpecimenArray, array.class, "Created instance class incorrect")
    assert_same(@type, array.container_type, "Created array type incorrect")
  end

  def test_save
    verify_save(@type)
  end
end