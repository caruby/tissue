$:.unshift 'lib'
$:.unshift '../caruby/lib'

require "test/unit"
require 'caruby/util/log'
require 'caruby/util/uniquifier'
require 'catissue/database/controlled_values'

class ControlledValuesTest < Test::Unit::TestCase
  LOG_FILE = 'test/results/catissue/log/catissue.log'

  def setup
    CaRuby::Log.instance.open(LOG_FILE, :debug => true)
  end

# works but takes a long time
#  def test_search_by_public_id
#    tissue_sites = CaTissue::ControlledValues.instance.for_public_id(:tissue_site)
#    assert_not_nil(tissue_sites, "Tissue site CVs not loaded")
#    parent = tissue_sites.detect { |cv| cv.value == 'DIGESTIVE ORGANS' }
#    assert_not_nil(parent, "DIGESTIVE ORGANS tissue site CVs not loaded")
#    child = parent.children.detect { |cv| cv.value == 'ESOPHAGUS' }
#    assert_not_nil(child, "DIGESTIVE ORGANS CV missing ESOPHAGUS child")
#    gc = child.children.detect { |cv| cv.value == 'Esophagus, NOS' }
#    assert_not_nil(gc, "ESOPHAGUS CV missing 'Esophagus, NOS' child")
#    assert(!parent.children.include?(gc), "DIGESTIVE ORGANS CV children incorrectly includes ESOPHAGUS child")
#    assert(parent.descendants.include?(gc), "DIGESTIVE ORGANS CV missing 'Esophagus, NOS' descendant")
#  end

  def test_find
    assert_not_nil(CaTissue::ControlledValues.instance.find(:tissue_site, 'Esophagus, NOS'), "'Esophagus, NOS' CV not found")
  end

  def test_find_case_insensitive
    assert_not_nil(CaTissue::ControlledValues.instance.find(:tissue_site, 'esophagus, NOS'), "Case-insensitive look-up inoperative")
  end

  def test_create_delete
    cv = CaTissue::ControlledValue.new
    cv.public_id = :tissue_site
    cv.value = 'Test Tissue Site'.uniquify
    assert_same(cv, CaTissue::ControlledValues.instance.create(cv), "CV not created")
    assert_same(cv, CaTissue::ControlledValues.instance.find(cv.public_id, cv.value), "Created CV not found")
    assert_nothing_raised("CV not deleted") { CaTissue::ControlledValues.instance.delete(cv) }
    assert_nil(CaTissue::ControlledValues.instance.find(cv.public_id, cv.value), "Deleted CV found")
  end
end