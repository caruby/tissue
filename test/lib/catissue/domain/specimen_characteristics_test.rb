require File.dirname(__FILE__) + '/../../../helpers/test_case'

class SpecimenCharacteristicsTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @chr = defaults.specimen_requirement.characteristics
  end

  def test_defaults
    verify_defaults(@chr)
  end
  
  def test_json
    verify_json(@chr)
  end
end
