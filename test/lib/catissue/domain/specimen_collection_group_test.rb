require File.join(File.dirname(__FILE__), '..', 'test_case')

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
    assert_not_nil(@scg.collection_event_parameters, "#{@scg} default CEP not created")
  end

  def test_default_collection_event
    collection_event = @scg.collection_event
    @scg.collection_event = nil
    assert_nil(@scg.collection_event, 'Collection event not removed')
    @scg.add_defaults
    assert_equal(collection_event, @scg.collection_event, 'Collection event not set to default')
  end

  def test_prostate_annotation
    scg = CaTissue::SpecimenCollectionGroup.new
    assert(CaTissue::SpecimenCollectionGroup.annotation_attribute?(:radical_prostatectomy_pathology_annotations))
    pas = scg.radical_prostatectomy_pathology_annotations
    assert(pas.empty?, "Prostatectomy annotations not empty at start")
    pa = CaTissue::SpecimenCollectionGroup::Pathology::RadicalProstatectomyPathologyAnnotation.new
    pa.merge_attributes(:specimen_procedure => 'Biopsy', :specimen_collection_group => scg)
    epx = CaTissue::SpecimenCollectionGroup::Pathology::ExtraprostaticExtension.new
    epx.merge_attributes(:status => 'Present', :radical_prostatectomy_pathology_annotation => pa)
    pas = scg.radical_prostatectomy_pathology_annotations
    assert_not_nil(pas.first, "Prostatectomy annotation not added to #{scg} annotations")
    assert_same(pa, pas.first, "Prostatectomy annotation incorrect")
    assert_same(scg, pa.owner, "Prostatectomy annotation proxy hook not set")
    assert_not_nil(pa.extraprostatic_extension, "#{pa} extraprostatic extension not set")
    assert_same(epx, pa.extraprostatic_extension, "{pa} extraprostatic extension incorrect")
  end
  
  def test_collect
    scg = CaTissue::SpecimenCollectionGroup.new
    cdt = DateTime.now
    scg.collect(:collector => @scg.collector, :collection_date => cdt, :receiver => @scg.receiver)
    assert_not_nil(scg.collection_event_parameters, "Collected SCG missing collection event parameters")
    assert_same(@scg.collector, scg.collection_event_parameters.user, "SCG collector incorrect")
    assert_equal(cdt.to_s, scg.collection_event_parameters.timestamp.to_s, "SCG collection time incorrect")
    assert_not_nil(scg.received_event_parameters, "Received SCG missing received event parameters")
    assert_same(@scg.receiver, scg.received_event_parameters.user, "SCG receiver incorrect")
    assert_equal(cdt.to_s, scg.received_event_parameters.timestamp.to_s, "SCG received time not defaulted to collection time")
  end

  def test_add_specimens
    cpe = @scg.collection_event
    rcvr = defaults.tissue_bank.coordinator
    reg = @scg.registration
    pnt = reg.participant
    pcl = reg.protocol
    rqmt = defaults.specimen_requirement
    spc1 = CaTissue::Specimen.create_specimen(:requirement => rqmt, :initial_quantity => 1.0)
    spc2 = CaTissue::Specimen.create_specimen(:requirement => rqmt, :initial_quantity => 1.0)
    site = defaults.tissue_bank
    scg = pcl.add_specimens(spc1, spc2, :participant => pnt, :site => site, :collection_event => cpe, :receiver => rcvr)
    cpr = scg.registration
    assert_not_nil(cpr, "#{scg} CPR not set")
    assert_not_nil(cpr.participant, "#{cpr} participant not set")
    assert_same(cpr.participant, pnt, "#{cpr} participant incorrect")
    assert_not_nil(scg.receiver, "#{scg} receiver not set")
    assert_same(rcvr, scg.receiver, "#{scg} receiver incorrect")
    assert_not_nil(scg.site, "#{scg} site not set")
    assert_same(site, scg.site, "#{scg} site incorrect")
    spcs = scg.specimens
    assert(spcs.include?(spc1), "#{spc1} not found in #{scg}")
    assert(spcs.include?(spc2), "#{spc2} not found in #{scg}")
  end

   ## DATABASE TEST CASES ##
  

  def test_save
    logger.debug { "Verifying SCG create..." }
    verify_save(@scg)
    assert_equal('Complete', @scg.collection_status, "Collection status after store incorrect")
    assert_equal(2, @scg.events.size, "#{@scg} events size incorrect")
    tmpl = @scg.copy(:identifier)
    verify_query(tmpl, :events) do |fetched|
      assert_equal(2, fetched.size, "#{@scg} fetched events size incorrect")
    end
    assert_equal(1, @scg.specimens.size, "#{@scg} specimens size incorrect")
    spc = @scg.specimens.first
    assert_equal(2, spc.events.size, "#{@scg} #{spc} events size incorrect")
    verify_query(spc, :events) do |fetched|
      assert_equal(2, fetched.size, "#{@scg} #{spc} events query result size incorrect")
    end

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
      assert_equal(1, fetched.size, "#{@scg} specimens query result size incorrect")
      spc = fetched.first
      assert_equal(@scg.specimens.first.identifier, spc.identifier, "#{@scg} fetched #{spc} identifier incorrect")
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
    site = defaults.tissue_bank
    scg = pcl.add_specimens(spc1, spc2, :participant => pnt, :site => site, :collection_event => cpe, :receiver => rcvr)
    verify_save(scg)
    spcs = scg.query(:specimens)
    spc_ids = spcs.map { |spc| spc.identifier }
    assert_equal(2, spcs.size, "#{scg} specimens size incorrect")
    assert(spc_ids.include?(spc1.identifier), "#{scg} specimen #{spc1} not found")
    assert(spc_ids.include?(spc2.identifier), "#{scg} specimen #{spc2} not found")
  end

  # This test follows caTissue SCG, SEP and Specimen auto-generation as follows:
  # * Create CPR => SCG auto-generated with status Pending, new Specimen, no SCG SEP
  # * Update SCG status to Complete => SCG SEP created
  def test_autogenerated
    # make a new registration
    pnt = CaTissue::Participant.new(:name => 'Test Participant'.uniquify)
    pcl = defaults.protocol
    cpr = pcl.register(pnt)

    # store the registration without an SCG
    verify_save(cpr)
    # the auto-generated SCG
    logger.debug { "#{self.class.qp} verifying the #{cpr} auto-generated SCG content..." }
    scg = cpr.specimen_collection_groups.first
    assert_not_nil(scg, "Missing auto-generated #{cpr} SCG")
    assert_not_nil(scg.identifier, "Auto-generated #{scg} missing identifier")
    assert_not_nil(scg.collection_event, "Auto-generated #{scg} missing collection event")
    assert_equal('Pending', scg.collection_status, "Auto-generated #{scg} status is not Pending")
    # the auto-generated Specimen
    spc = scg.specimens.first
    assert_not_nil(spc, "Auto-generated #{scg} specimen was not fetched")
    # SEP is not auto-generated
    assert(scg.specimen_event_parameters.empty?, "#{scg} SEP unexpectedly auto-generated")
    # auto-generated SCG CPR has a protocol and PPI
    cpr = scg.collection_protocol_registration
    assert_not_nil(cpr, "Auto-generated #{scg} CPR not set")
    assert_not_nil(cpr.protocol, "Auto-generated #{scg} CPR #{cpr} protocol not set")
    assert_not_nil(cpr.protocol_participant_identifier, "Auto-generated #{scg} #{cpr} PPI not set")
    # auto-generated SCG does not have a site, even though it is required for create or update
    assert_nil(scg.collection_site, "SCG collection site unexpectedly auto-generated")

    # update the SCG with site and SEPs
    rcvr = defaults.tissue_bank.coordinator
    site = defaults.specimen_collection_group.collection_site
    scg.merge_attributes(:receiver => rcvr, :collection_site => site).add_defaults
    logger.debug { "#{self.class.qp} updating the auto-generated #{scg.qp}..." }
    verify_save(scg)
    # clear and refetch the status
    scg.collection_status = nil
    logger.debug { "#{self.class.qp} refetching the updated #{scg.qp}..." }
    scg.find
    assert_equal('Pending', spc.collection_status, "Auto-generated #{spc} status is not Pending after update")

    # reset some specimen fields and update
    spc.collection_status = 'Collected'
    spc.specimen_type = 'Frozen Tissue'
    spc.initial_quantity = 0.1
    spc.specimen_characteristics.tissue_site = 'Ileum'
    logger.debug { "#{self.class.qp} updating auto-generated #{spc.qp}..." }
    verify_save(spc)

    # clear and refetch some specimen fields
    spc.collection_status = nil
    spc.specimen_characteristics.tissue_site = nil
    logger.debug { "#{self.class.qp} verifying the persistent state of the updated #{scg.qp} auto-generated specimen..." }
    database.find(spc)
    assert_equal('Collected', spc.collection_status, "#{spc} status not updated")
    assert_equal('Ileum', spc.specimen_characteristics.tissue_site, "#{spc} tissue site not updated")

    # update the SCG with complete status
    scg.collection_status = 'Complete'
    logger.debug { "#{self.class.qp} updating the #{scg.qp} collection status #{scg.qp}..." }
    scg.update
    verify_save(scg)
  end

  # Tests saving a SCG in a CPR which already has a different SCG.
  def test_create_extra_scg
    cpe = @scg.collection_event
    rcvr = defaults.tissue_bank.coordinator
    reg = @scg.registration
    pnt = reg.participant
    pcl = reg.protocol
    rqmt = defaults.specimen_requirement
    spc = CaTissue::Specimen.create_specimen(:requirement => rqmt, :initial_quantity => 1.0)
    site = defaults.tissue_bank
    scg = pcl.add_specimens(spc, :participant => pnt, :site => site, :collection_event => cpe, :receiver => rcvr)
    assert_not_nil(scg.received_event_parameters, "#{scg} missing REP")
    verify_save(scg)
  end
  
  def test_save_prostate_annotation
    pa = CaTissue::SpecimenCollectionGroup::Pathology::RadicalProstatectomyPathologyAnnotation.new
    pa.specimen_collection_group = @scg
    htype = CaTissue::SpecimenCollectionGroup::Pathology::HistologicType.new
    htype.merge_attributes(:type => 3, :base_pathology_annotation => pa)
    grade = CaTissue::SpecimenCollectionGroup::Pathology::HistologicGrade.new
    grade.merge_attributes(:grade => 3, :base_solid_tissue_pathology_annotation => pa)
    invn = CaTissue::SpecimenCollectionGroup::Pathology::Invasion.new
    invn.merge_attributes(:lymphatic_invasion => 'Present', :base_solid_tissue_pathology_annotation => pa)
    gleason = CaTissue::SpecimenCollectionGroup::Pathology::GleasonScore.new
    gleason.merge_attributes(:primary_pattern_score => 3, :secondary_pattern_score => 4, :prostate_pathology_annotation => pa)
    margin = CaTissue::SpecimenCollectionGroup::Pathology::RadicalProstatectomyMargin.new
    margin.merge_attributes(:margin_status => 'Benign glands at surgical Margin', :radical_prostatectomy_pathology_annotation => pa)
    verify_save(pa)
    assert_not_nil(pa.identifier, "#{@scg} annotation #{pa} not saved")
    assert_not_nil(htype.identifier, "#{@scg} annotation #{htype} not saved")
    assert_not_nil(grade.identifier, "#{@scg} annotation #{grade} not saved")
    assert_not_nil(invn.identifier, "#{@scg} annotation #{invn} not saved")
    assert_not_nil(gleason.identifier, "#{@scg} annotation #{gleason} not saved")
    assert_not_nil(margin.identifier, "#{@scg} annotation #{margin} not saved")
  end
  
  # Tests saving a participant lab annotation indirectly by saving a SCG. 
  def test_save_lab_annotation_by_saving_scg
    pnt = @scg.collection_protocol_registration.participant
    date = DateTime.new(2010, 10, 10)
    labs = CaTissue::Participant::Clinical::LabAnnotation.new
    labs.merge_attributes(:other_lab_test_name => 'Test Lab', :test_date => date, :participant => pnt)
    verify_save(@scg)
    assert_not_nil(labs.identifier, "#{@scg} participant #{pnt} labs not saved")
  end
end