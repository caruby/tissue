require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'caruby/util/uniquifier'

class ParticipantTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @pnt = CaTissue::Participant.new(:name => 'Test Participant'.uniquify)
  end

  def test_defaults
    verify_defaults(@pnt)
  end

  def test_name
    @pnt.name = 'John Q. Doe'
    assert_equal('John', @pnt.first_name, 'Person first name incorrect')
    assert_equal('Q.', @pnt.middle_name, 'Person middle name incorrect')
    assert_equal('Doe', @pnt.last_name, 'Person last name incorrect')
  end

  def test_key
    mrn = '5555'
    pmi = @pnt.add_mrn(defaults.tissue_bank, '5555')
    assert_equal(pmi, @pnt.key, 'Person key is not the MRN')
    # add the preferred SSN key
    expected = @pnt.social_security_number = '555-55-5555'
    assert_equal(expected, @pnt.key, 'Person key is not the SSN')
  end

  # Tests creating and fetching a participant.
  def test_save
    verify_save(@pnt)
  end
end