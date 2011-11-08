require File.dirname(__FILE__) + '/../helpers/test_case'

class UserTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @user = defaults.tissue_bank.coordinator
  end

#  # Verifies the secondary key.
#  def test_secondary_key
#    assert_equal(@user.login_name, @user.key, 'Key incorrect')
#  end
#
#  def test_defaults
#    verify_defaults
#  end
#
#  # Exercises setting the login name from the email address.
#  def test_default_login_value
#    @user.login_name = nil
#    verify_defaults
#  end
#
#  # Exercises setting the email address from the login name.
#  def test_default_email_value
#    @user.email_address = nil
#    verify_defaults
#  end
#
#  def verify_defaults
#    @user.address.identifier = 1
#    @user.cancer_research_group.identifier = 2
#    @user.department.identifier = 3
#    @user.institution.identifier = 4
#    super(@user)
#  end

  # Tests creating a user.
  def test_save
    addr = @user.email_address
    at_ndx = addr.index('@')
    modifier = "_#{CaRuby::Uniquifier.qualifier.to_s}"
    @user.email_address = addr.insert(at_ndx, modifier)
    @user.login_name = nil
    verify_save(@user)
  end
end