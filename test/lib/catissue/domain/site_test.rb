require File.dirname(__FILE__) + '/../../../helpers/test_case'

class SiteTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @site = defaults.tissue_bank
    @site.name = @site.name.uniquify
  end

  def test_defaults
    verify_defaults(@site)
  end
  
  def test_json
    verify_json(@site)
  end

  def test_save
    # create the site
    verify_save(@site)
    # modify the site address; this changes the existing address rather than creating a new address
    identifier = @site.address.identifier
    zip_code = @site.address.zip_code = @site.address.zip_code.to_i + 1
    verify_save(@site)
    # clear the address identifier zip code and refetch the site; this sets the zip code to the database value
    @site.address.identifier = @site.address.zip_code = nil
    database.find(@site)
    assert_equal(zip_code, @site.address.zip_code.to_i, "Updated zip code incorrect.")
    assert_equal(identifier, @site.address.identifier, "Address replaced rather than updated.")
  end
end
