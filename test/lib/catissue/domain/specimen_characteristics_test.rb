require File.join(File.dirname(__FILE__), '..', 'test_case')

class SpecimenCharacteristicsTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @chr = defaults.specimen_requirement.characteristics
  end

  def test_defaults
    verify_defaults(@chr)
  end
end
