require File.join(File.dirname(__FILE__), '..', 'test_case')

class CaTissueTestDefaultsTest < Test::Unit::TestCase
  include CaTissue::TestCase

  attr_reader :defaults

  def setup
    super
    @defaults = CaTissueTest::Defaults.instance
  end

  def test_validation
    assert_nothing_raised(ValidationError, "Defaults validation unsuccessful") { defaults.add_defaults.validate }
  end

  # Fetches the test data, creating new objects if necessary
  def test_find
    assert_nothing_raised(CaRuby::DatabaseError, "Defaults store unsuccessful") { defaults.each { |obj| database.find(obj) } }
  end

  # Store the test data
  def test_save
    defaults.each { |obj| verify_save(obj) }
  end
end