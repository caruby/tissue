require File.dirname(__FILE__) + '/../helpers/test_case'

class CollectionProtocolRegistrationTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @reg = defaults.registration
  end

  def test_defaults
    verify_defaults(@reg)
  end
  
  def test_missing_ppi_defaults
    @reg.protocol_participant_identifier = nil
    verify_defaults(@reg)
  end
  
  def test_inverse_protocol
    assert(@reg.protocol.registrations.include?(@reg), "Registration not included in protocol registrations")
  end
  
  def test_inverse_scgs
    assert(!@reg.specimen_collection_groups.empty?, "#{@reg} SCG is missing.")
  end
  
  # Tests whether the registration date can be set to either a Ruby or a Java Date and always return a Ruby Date.
  def test_registration_date
    value = DateTime.now
    @reg.registration_date = value
    assert_equal(value.to_s, @reg.registration_date.to_s, "Registration date incorrect")
  end
  
  def test_numeric_identifier
    @reg.protocol_participant_identifier = 1
    assert_equal("1", @reg.protocol_participant_identifier)
  end
  
  def test_disable
    # add a derived specimen
    spc = @reg.specimens.first
    assert_not_nil(spc, "#{@reg} specimen missing")
    child = spc.derive(:specimen_class => :molecular, :specimen_requirement => defaults.specimen_requirement)
    attributes = [:specimen_collection_groups, :specimens, :child_specimens]
    @reg.visit_path(attributes) { |obj| obj.activity_status = 'Disabled' }
    assert_equal('Disabled', @reg.activity_status, "#{@reg} not disabled")
    @reg.specimen_collection_groups.each { |scg| assert_equal('Disabled', scg.activity_status, "#{scg} not disabled") }
    @reg.specimens.each { |rspc| assert_equal('Disabled', rspc.activity_status, "#{rspc} not disabled") }
    assert_equal('Disabled', child.activity_status, "Child Specimen #{child} not disabled")
  end
  
  # Tests creating and fetching a registration.
  def test_save
    # store the registration without an SCG
    @reg.specimen_collection_groups.clear
    verify_save(@reg)
  
    # an SCG should be auto-generated
    scg = @reg.specimen_collection_groups.first
    assert_not_nil(scg, "Missing auto-generated SCG")
    # the SCG status is pending
    assert_equal('Pending', scg.collection_status, "Auto-generated SCG collection status incorrect")
  
    # modify the consent status and update
    rsps = @reg.consent_tier_responses
    assert_equal(1, rsps.size, "Consent tier responses size incorrect")
    rsp = rsps.first
    rsp.response = 'No'
    # clear the CPR SCGs since CPR response change propagates to SCG consent status on create,
    # which results in a test validation mismatch
    @reg.specimen_collection_groups.clear
    verify_save(@reg)
  end
end
