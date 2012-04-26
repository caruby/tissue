require File.dirname(__FILE__) + '/../../../helpers/test_case'

class CollectionProtocolTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @pcl = defaults.protocol
  end

  def test_defaults
    verify_defaults(@pcl)
  end

  # Tests the hash override.
  def test_hash
    hash = @pcl.hash
    map = {@pcl => true}
    @pcl.identifier = 1
    assert_equal(hash, @pcl.hash, "Protocol identifier assignment changed hash")
    assert(map[@pcl], "Protocol hash key inoperative")
  end

  def test_alias
    assert(CaTissue::CollectionProtocol.method_defined?(:events), "Protocol alias not recogized: events")
  end

  # Tests the work-around for caTissue bug - CollectionProtocol and CollectionProtocolEvent are equal in caTissue 1.1.
  def test_equals
    assert_not_equal(@pcl, CaTissue::CollectionProtocolEvent.new, "Protocol incorrectly equals a CollectionProtocolEvent")
  end

  # Tests whether the child_collection_protocols domain type is inferred from the Java parameterized generic type property.
  def test_assigned_protocol_users_type
    assert_equal(CaTissue::User, @pcl.class.domain_type(:assigned_protocol_users), "assigned_protocol_users domain type incorrect")
  end

  def test_add_specimens
    spc1 = CaTissue::TissueSpecimen.new
    spc2 = CaTissue::TissueSpecimen.new
    pnt = CaTissue::Participant.new(:name => 'Test Participant')
    rcvr = CaTissue::User.new(:login_name => 'test_coordinator@example.edu')
    site = CaTissue::Site.new(:name => 'Test Site')
    scg = @pcl.add_specimens(spc1, spc2, :participant => pnt, :receiver => rcvr, :collection_site => site)
    assert_equal(2, scg.size, "Specimen group size incorrect")
    assert_equal(2, scg.specimen_event_parameters.size, "Specimen event parameters size incorrect")
    assert_not_nil(scg.registration, "Specimen not registered")
    assert_equal(2, @pcl.specimens(pnt).size, "Protocol specimens size incorrect")
    assert(@pcl.specimens(pnt).include?(spc1), 'Specimen not found')
    assert(@pcl.specimens(pnt).include?(spc2), 'Specimen not found')
  end

  def test_events
    event = @pcl.events.first
    assert_not_nil(event, "Protocol test default has no events")
    event_cnt = @pcl.events.size
    @pcl.events << event
    assert_equal(event_cnt, @pcl.events.size, "Protocol events has duplicate event")
  end
  
  def test_json
    verify_json(@pcl)
  end

  def test_save
    # ignore registrations
    @pcl.collection_protocol_registrations.clear
    # create the protocol
   verify_save(@pcl)
  end
end
