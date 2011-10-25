require File.dirname(__FILE__) + '/../helpers/test_case'
require 'caruby/util/uniquifier'

class AddressTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    # make the unique test address
    @user = defaults.tissue_bank.coordinator
    @addr = @user.address
  end

  def test_defaults
    verify_defaults(@addr)
  end
  
  def test_zip_code
    @addr.zip_code = 55555
    assert_equal('55555', @addr.zip_code, "Integer zip code value is not correctly transformed")
  end

  def test_save
    # Create the address.
    verify_save(@addr)
    # Modify the address.
    expected = @addr.street = "#{Uniquifier.qualifier} Elm"
    verify_save(@addr)
    # Find the address.
    fetched = @addr.copy(:identifier).find
    assert_equal(expected, fetched.street, "Address street not saved")
  end
end
