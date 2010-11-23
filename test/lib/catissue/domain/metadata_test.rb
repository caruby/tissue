require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'caruby/util/uniquifier'

class MetadataTest < Test::Unit::TestCase
  include CaTissue::TestCase

  OVERRIDE_CONFIG_FILE = 'test/fixtures/catissue/domain/conf/catissue_override.yaml'

  def setup
    super
    @metadata = CaTissue::CollectionProtocol.metadata
  end

  def test_domain_attribute
    assert(!@metadata.domain_attribute?(:title), 'String attribute considered domain attribute')
    assert(@metadata.domain_attribute?(:collection_protocol_events), 'Domain collection attribute not recognized')
  end

  def test_collection_attribute
    assert(!@metadata.collection_attribute?(:principal_investigator), 'Atomic attribute considered a collection')
    assert(@metadata.collection_attribute?(:collection_protocol_events), 'Domain collection attribute not recognized as collection')
  end

  def test_invalid_attribute
    assert(!@metadata.attributes.include?(:parent_collection_protocol), 'Attribute marked as invalid recognized')
  end

  def test_secondary_key
    assert(!@metadata.secondary_key_attributes.empty?, 'Secondary key not set')
    assert_equal([:short_title], @metadata.secondary_key_attributes.to_a, 'Secondary key incorrect')
  end

  def test_mandatory_attributes
    assert(@metadata.mandatory_attributes.include?(:short_title), 'Secondary key not in required key')
    assert(@metadata.mandatory_attributes.include?(:start_date), 'Required attribute not found')
  end

  # TODO - enable config override and retest.

  def test_secondary_key_override
    # save the standard properties
    properties = CaTissue.access_properties.copy_recursive
    # load the override properties
    CaTissue.load_access_properties(OVERRIDE_CONFIG_FILE)
    @metadata = CaRuby::Metadata.new(CaTissue::CollectionProtocol)
    assert_equal([:title], @metadata.secondary_key_attributes, 'Secondary key not overridden')
    # restore the standard properties
    CaTissue.access_properties.keys.each { |key| CaTissue.access_properties[key] = properties[key] }
  end

  def test_mandatory_attributes_override
    # save the standard properties
    properties = CaTissue.access_properties.copy_recursive
    # load the override properties
    CaTissue.load_access_properties(OVERRIDE_CONFIG_FILE)
    @metadata = CaRuby::Metadata.new(CaTissue::CollectionProtocol)
    assert(@metadata.mandatory_attributes.include?(:sequence_number), 'Required attribute override not added')
    assert(!@metadata.mandatory_attributes.include?(:start_date), 'Required attribute retained after override')
    # restore the standard properties
    CaTissue.access_properties.keys.each { |key| CaTissue.access_properties[key] = properties[key] }
  end
end