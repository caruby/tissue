require File.dirname(__FILE__) + '/../../../helpers/test_case'
require 'jinx/helpers/uniquifier'

class CaTissueDepartmentTest < Test::Unit::TestCase
  include CaTissue::TestCase

  attr_reader :department

  def setup
    super
    @department = CaTissue::Department.new(:name => 'Test Department'.uniquify)
  end

  def test_defaults
    verify_defaults(department)
  end

  def test_save
    verify_save(department)
  end
end
