require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'caruby/util/uniquifier'

class AddressTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    # make the unique test address
    @address = CaTissue::Address.new
    @address.city = 'Test City'
    @address.state = 'Other'
    @address.country = 'US'
    @address.zip_code = '55555'
    @address.street = '555'.uniquify + ' Test St'
    @address.phone_number = '555-555-5555'
  end

  # Tests the key method for a domain class without a secondary key.
  def test_non_secondary_key
    # make an address
    @address = CaTissue::Address.new
    @address.identifier = 1
    expected = @address.identifier
    assert_equal(expected, @address.key, 'Key incorrect')
  end

  def test_defaults
    verify_defaults(@address)
  end

  def test_merge_identifier
    from = CaTissue::User.new(:address => @address)
    to = CaTissue::User.new(:address => @address.copy)
    from.address.identifier = 555
    to.merge_attributes(from)
    assert_equal(555, to.address.identifier, "Address identifier not merged")
  end

  def test_save
    database.create(@address)
    assert_not_nil(@address.identifier, "Address not created")
    @address.zip_code = '111111'
    @address.phone_number = nil
    database.update(@address)
    template = @address.copy
    template.zip_code = nil
    fetched = database.query(template).first
    assert_not_nil(fetched, "Address not found")
    assert_equal('111111', fetched.zip_code, "Address zipcode not updated")
    assert_nil(fetched.phone_number, "Address phone number not cleared by update")
  end
end