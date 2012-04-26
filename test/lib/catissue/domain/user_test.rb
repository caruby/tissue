require File.dirname(__FILE__) + '/../../../helpers/test_case'

class UserTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @user = defaults.tissue_bank.coordinator
  end

  # Verifies the secondary key.
  def test_secondary_key
    assert_equal(@user.login_name, @user.key, 'Key incorrect')
  end

  def test_defaults
    verify_defaults(@user)
  end
  
  def test_json
    verify_json(@user)
  end

  # Exercises setting the login name from the email address.
  def test_default_login_value
    @user.login_name = nil
    verify_defaults(@user)
  end

  # Exercises setting the email address from the login name.
  def test_default_email_value
    @user.email_address = nil
    verify_defaults(@user)
  end

  # Tests creating a user and updating the address.
  def test_save
    # Create the user with a unique email.
    email = @user.email_address
    at_ndx = email.index('@')
    modifier = "_#{Jinx::Uniquifier.qualifier}"
    @user.email_address = email.insert(at_ndx, modifier)
    @user.login_name = nil
    verify_save(@user)
    
    # Update the address.
    logger.debug { "#{self} updating the #{@user} address..." }
    @user.address.street = "#{Jinx::Uniquifier.qualifier} Elm St."
    verify_save(@user)
  end
end