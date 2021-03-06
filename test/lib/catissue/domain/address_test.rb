require File.dirname(__FILE__) + '/../../../helpers/test_case'

class AddressTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    # make the unique test address
    @user = defaults.tissue_bank.coordinator
    @addr = @user.address
  end
  
  def test_primary_key
    assert_equal([:identifier], CaTissue::Address.primary_key_attributes, "Primary key is not the identifier")
  end

  def test_defaults
    verify_defaults(@addr)
  end
  
  def test_json
    verify_json(@addr)
  end
  
  def test_zip_code
    @addr.zip_code = 55555
    assert_equal('55555', @addr.zip_code, "Integer zip code value is not correctly transformed")
  end

  def test_save
    # Address cannot be created.
    assert_raises(CaRuby::DatabaseError, "Address create is incorrectly allowed.") { @addr.create }
  end
end
