require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'test/fixtures/lib/catissue/defaults_test_fixture'

class CollectionProtocolEventTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @evt = defaults.specimen_collection_group.collection_event
  end

  def test_defaults
    @evt.protocol.identifier = 1
    verify_defaults(@evt)
  end

  def test_protocol_membership
    assert(@evt.protocol.collection_protocol_events.include?(@evt), "Event not a member of its protcol events collection")
  end

  # Tests creating a protocol event.
  def test_save
    verify_save(@evt)
  end
end
