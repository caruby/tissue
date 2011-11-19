require File.dirname(__FILE__) + '/../../helpers/test_case'
require 'caruby/helpers/uniquifier'
require 'catissue/database/controlled_values'

class ControlledValuesTest < Test::Unit::TestCase
  
  def test_search_by_public_id
    races = CaTissue::ControlledValues.instance.for_public_id('Race_PID')
    assert_not_nil(races, "Race CVs not loaded")
    assert_not_nil(races.detect { |cv| cv.value == 'White' }, "Race not found")
  end

  def test_find
    cv = CaTissue::ControlledValues.instance.find(:tissue_site, 'Esophagus, NOS')
    assert_not_nil(cv, "'Esophagus, NOS' CV not found")
  end

  def test_find_case_insensitive
    cv = CaTissue::ControlledValues.instance.find(:tissue_site, 'esophagus, NOS')
    assert_not_nil(cv, "Case-insensitive look-up inoperative")
  end

  def test_find_recursive
    gp = CaTissue::ControlledValues.instance.find(:tissue_site, 'DIGESTIVE ORGANS', true)
    assert_not_nil(gp, "DIGESTIVE ORGANS CV not found")
    assert(!gp.children.empty?, "CV missing children")
    parent = gp.children.detect { |cv| cv.value == 'ESOPHAGUS' }
    assert_not_nil(parent, "DIGESTIVE ORGANS 'ESOPHAGUS' child CV not found")
    child = parent.children.detect { |cv| cv.value == 'Esophagus, NOS' }
    assert_not_nil(child, "ESOPHAGUS 'Esophagus, NOS' child CV not found")
    assert(gp.descendants.include?(child), "DIGESTIVE ORGANS CV missing 'Esophagus, NOS' descendant")
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