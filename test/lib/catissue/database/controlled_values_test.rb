require File.dirname(__FILE__) + '/../../../helpers/test_case'
require 'jinx/helpers/uniquifier'
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
    root = CaTissue::ControlledValues.instance.find(:tissue_site, 'DIGESTIVE ORGANS', true)
    assert_not_nil(root, "'DIGESTIVE ORGANS' CV not found")
    assert(!root.children.empty?, "#{root} missing children")
    stomach = root.children.detect { |cv| cv.value == 'STOMACH' }
    assert_not_nil(stomach, "#{root} STOMACH child CV not found")
    pylorus = stomach.children.detect { |cv| cv.value == 'Pylorus' }
    assert_not_nil(pylorus, "#{pylorus} Pylorus child CV not found")
    assert(stomach.descendants.include?(pylorus), "#{root} CV missing #{pylorus} descendant")
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
