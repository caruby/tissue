require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'test/fixtures/lib/catissue/defaults_test_fixture'

class SpecimenCollectionGroupTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @scg = defaults.specimen_collection_group
  end

  # This test case exercises the key method for a domain class with a secondary key.
  def test_secondary_key
    @scg.name = 'Test SCG'
    assert_equal(@scg.name, @scg.key, 'Key incorrect')
  end

  def test_defaults
    verify_defaults(@scg)
    assert_equal('Complete', @scg.collection_status, "SCG collection status default incorrect")
    @scg.registration.consent_tier_responses.each do |ctr|
      ct = ctr.consent_tier
      cts = @scg.consent_tier_statuses.detect { |s| s.consent_tier == ct }
      assert_not_nil(cts, "Missing SCG consent tier status for #{ct}")
    end
  end

  def test_default_collection_event
    collection_event = @scg.collection_event
    @scg.collection_event = nil
    assert_nil(@scg.collection_event, 'Collection event not removed')
    @scg.add_defaults
    assert_equal(collection_event, @scg.collection_event, 'Collection event not set to default')
  end

# TODO - finish DE and enable
#  def test_base_haematology_pathology
#    assert(CaTissue::SpecimenCollectionGroup.class.annotation_attributes.include?(:base_haematology_pathology), "Missing base_haematology_pathology annotation attribute")
#    assert(CaTissue::SpecimenCollectionGroup.const_defined?(:BaseHaematologyPathologyAnnotation), "Missing BaseHaematologyPathologyAnnotation annotation class")
#    annotation = add_base_haematology_pathology_annotation
#    assert_same(CaTissue::SpecimenCollectionGroup::HistologicType, annotation.class.domain_type(:histologic_type), "BaseHaematologyPathologyAnnotation histologic_type domain type incorrect")
#  end
#
  def test_collect
    scg = CaTissue::SpecimenCollectionGroup.new
    collection_date = DateTime.now
    scg.collect(:collector => @scg.collector, :collection_date => collection_date, :receiver => @scg.receiver)
    assert_not_nil(scg.collection_event_parameters, "Collected SCG missing collection event parameters")
    assert_same(@scg.collector, scg.collection_event_parameters.user, "SCG collector incorrect")
    assert(Resource.value_equal?(collection_date, scg.collection_event_parameters.timestamp), "SCG collection time incorrect")
    assert_not_nil(scg.received_event_parameters, "Received SCG missing received event parameters")
    assert_same(@scg.receiver, scg.received_event_parameters.user, "SCG receiver incorrect")
    assert_equal(Resource.value_equal?(collection_date, scg.received_event_parameters.timestamp), "SCG received time not defaulted to collection time")
  end

  def test_save
    logger.debug { "Verifying SCG create..." }
    verify_save(@scg)
    assert_equal('Complete', @scg.collection_status, "Collection status after store incorrect")

    # test update
    @scg.diagnosis = 'Pleomorphic carcinoma'
    # set an event comment
    cep = @scg.specimen_event_parameters.detect { |param| CaTissue::CollectionEventParameters === param }
    cep.comment = 'Test Comment'
    verify_save(@scg)

    # query the specimens
    logger.debug { "Verifying #{@scg.qp} specimens query..." }
    tmpl = @scg.copy(@scg.class.secondary_key_attributes)
    verify_query(tmpl, :specimens) do |fetched|
      assert_equal(1, fetched.size, "Specimens query result size incorrect")
      assert_equal(@scg.specimens.first.identifier, fetched.first.identifier, "Specimen identifier incorrect")
    end

    # query the collection event parameters
    logger.debug { "Verifying that #{@scg.qp} specimen_event_parameters are created..." }
    verify_query(tmpl) do |fetched|
      assert_equal(@scg.specimen_event_parameters.size, fetched.first.specimen_event_parameters.size, "Event query result size incorrect")
      # the fetched CEP
      fcep = fetched.first.specimen_event_parameters.detect { |param| CaTissue::CollectionEventParameters === param }
      assert_not_nil(fcep, "Collection event missing")
      assert_equal('Test Comment', fcep.comment, "Collection event comment not saved")
    end

    # update the comment
    logger.debug { "Verifying #{@scg.qp} update..." }
    @scg.comment = comment = 'Test Comment'
    verify_save(@scg)
    @scg.comment = nil
    database.find(@scg)
    assert_equal(comment, @scg.comment, "Comment not updated in database")
    logger.debug { "Verified #{@scg.qp} store." }

    # create a new SCG with two specimens
    logger.debug { "Verifying second SCG create..." }
    cpe = @scg.collection_event
    rcvr = defaults.tissue_bank.coordinator
    reg = @scg.registration
    pnt = reg.participant
    pcl = reg.protocol
    rqmt = defaults.specimen_requirement
    spc1 = CaTissue::Specimen.create_specimen(:requirement => rqmt, :initial_quantity => 1.0)
    spc2 = CaTissue::Specimen.create_specimen(:requirement => rqmt, :initial_quantity => 1.0)
    scg = pcl.add_specimens(spc1, spc2, :participant => pnt, :collection_event => cpe, :receiver => rcvr)
    verify_save(scg)
  end
end