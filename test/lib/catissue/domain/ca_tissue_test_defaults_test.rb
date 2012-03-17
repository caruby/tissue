require File.dirname(__FILE__) + '/../../../helpers/test_case'

class CaTissueTestDefaultsTest < Test::Unit::TestCase
  include CaTissue::TestCase

  # Validates the #{CaTissue::TestCase::Seed} data.
  def test_validation
    assert_nothing_raised(Jinx::ValidationError, "Defaults validation unsuccessful") { defaults.add_defaults.validate }
  end

  # Saves the #{CaTissue::TestCase::Seed} data.
  def test_save
    defaults.domain_objects.each { |obj| verify_save(obj) }
  end
end