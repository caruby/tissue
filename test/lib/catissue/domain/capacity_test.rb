require File.dirname(__FILE__) + '/../../helpers/test_case'

class CapacityTest < Test::Unit::TestCase
  include CaTissue::TestCase

  # Verifies the :rows and :columns aliases.
  def test_merge_attributes
    cpc = CaTissue::Capacity.new(:columns => 5, :rows => 5)
    assert_equal(5, cpc.one_dimension_capacity, "Rows incorrect")
    assert_equal(5, cpc.two_dimension_capacity, "Columns incorrect")
  end
end