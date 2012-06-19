require File.dirname(__FILE__) + '/../../../helpers/test_case'

class CaTissueDepartmentTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @dept = CaTissue::Department.new(:name => Jinx::StringUniquifier.uniquify('Test Department'))
  end

  def test_defaults
    verify_defaults(@dept)
  end
  
  def test_json
    verify_json(@dept)
  end

  def test_save
    verify_save(@dept)
  end
end
