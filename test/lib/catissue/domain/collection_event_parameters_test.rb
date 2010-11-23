require File.join(File.dirname(__FILE__), '..', 'test_case')

class CollectionEventParametersTest < Test::Unit::TestCase
  include CaTissue::TestCase

  attr_reader :event_params

  def setup
    super
    scg = CaTissue::SpecimenCollectionGroup.new
    collector = CaTissue::User.new
    @event_params = CaTissue::SpecimenEventParameters.create_parameters(:collection, scg, :user => collector)
  end

  def test_defaults
    event_params.add_defaults
    assert_not_nil(event_params.timestamp, 'Timestamp not set to default')
  end
  
  # Test updating an auto-created CollectionEventParameters
  def test_create
    
  end
end