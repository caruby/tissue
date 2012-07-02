require File.dirname(__FILE__) + '/../../../helpers/test_case'
require 'jinx/helpers/transitive_closure'

class SpecimenTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @spc = defaults.specimen
  end

  def test_requirement_copy
    rqmt = @spc.requirement
    rqmt.value_hash(rqmt.class.nondomain_attributes).each do |pa, value|
      assert_equal(value, @spc.send(pa), "Specimen requirement #{pa} not copied")
    end
  end

  def test_characteristics
    chrs = @spc.specimen_characteristics
    assert_not_nil(chrs, "Specimen characterstics not found")
  end

  def test_defaults
    @spc.lineage = @spc.specimen_class = @spc.specimen_characteristics = nil
    verify_defaults(@spc)
    # specimen class is set as a default value
    assert_equal("Tissue", @spc.specimen_class, "Specimen class incorrect")
    # the characteristics default is set as a default value
    assert_not_nil(@spc.specimen_characteristics, "Specimen characteristics not set to default")
    # collectible events are propagated from the SCG
    assert_not_nil(@spc.collection_event_parameters, "#{@spc} missing collection event")
    assert_not_nil(@spc.received_event_parameters, "#{@spc} missing received event")
  end

  # Tests whether the child_specimens domain type is overridden in the configuration from the
  # inferred Java parameterized generic type property.
  def test_child_specimens_type
    assert_equal(CaTissue::Specimen, @spc.class.domain_type(:child_specimens), "child_specimen domain type not overridden in configuration to non-abstract Specimen")
  end

  def test_parent
    @spc.parent = CaTissue::TissueSpecimen.new
    assert_equal(1, @spc.parent.children.size, "Specimen children size incorrect")
    assert_equal(@spc, @spc.parent.children.first, "Specimen parent incorrect")
  end

  def test_transitive_closure
    @spc.parent = CaTissue::TissueSpecimen.new
    # take the transitive closure of specimens in the hierarchy
    closure = [@spc.parent].transitive_closure(:children)
    assert(closure.include?(@spc.parent), "Specimen transitive closure does not contain parent")
    assert(closure.include?(@spc), "Specimen transitive closure does not contain child")
  end
  
  def test_collect
    @spc.collect(:receiver => @spc.specimen_collection_group.receiver)
    assert_not_nil(@spc.received_event_parameters, "Collected #{@spc} missing REP")
    assert_not_nil(@spc.collection_event_parameters, "Collected #{@spc} missing CEP")
  end

  def test_move
    # add to the default box
    box = defaults.box << @spc
    pos = @spc.position
    assert_not_nil(pos, "Specimen position not set")
    assert_same(@spc, pos.specimen, "Specimen position specimen incorrect")
    # test move from box to another box
    dest = box.copy
    dest.container_type = box.container_type
    @spc >> dest
    assert_same(dest, @spc.position.container, "Specimen position container incorrect")
    assert(dest.include?(@spc), "Destination #{box.qp} doesn't hold specimen #{@spc.qp}")
    assert(!box.include?(@spc), "Old box #{box.qp} still holds specimen #{@spc.qp}")
    # move back to original position
    @spc.move_to(box, pos.column, pos.row)
    assert_same(box, @spc.position.container, "Specimen position container incorrect")
    assert(!dest.include?(@spc), "Move source #{dest.qp} still holds specimen #{@spc.qp}")
    assert(box.include?(@spc), "Move destination #{box.qp} doesn't hold specimen #{@spc.qp}")
  end

  def test_derive
    start_quantity = @spc.available_quantity
    child_quantity = start_quantity / 2
    child = @spc.derive(:specimen_class => :molecular, :specimen_type => 'DNA', :initial_quantity => child_quantity)
    assert_equal(CaTissue::MolecularSpecimen, child.class, "Derived specimen class incorrect")
    assert_same(@spc, child.parent, "Derived specimen parent incorrect")
    assert(@spc.children.include?(child), "Child specimens does not include the derived specimen")
    assert_equal(child_quantity, child.initial_quantity, "Child specimen quantity incorrect")
    # parent quantity not automatically decremented, since parent and child types differ
    assert_equal(start_quantity, @spc.available_quantity, "Parent specimen quantity not decremented correctly")
  end

  def test_derive_defaults
    child = @spc.derive
    assert_same(@spc.class, child.class, "Derived specimen class incorrect")
    assert_equal(@spc.specimen_type, child.specimen_type, "Derived specimen type incorrect")
    assert_equal(@spc.pathological_status, child.pathological_status, "Derived specimen pathological status incorrect")
  end

  def test_aliquot
    start_qty = @spc.available_quantity
    # the number of aliquots
    count = 2
    # the aliqout quantity
    alq_qty = start_qty / 4
    # the expected parent quantity
    par_qty = start_qty - (alq_qty * count)
    # make the aliquots
    alqs = @spc.derive(:count => count, :initial_quantity => alq_qty)
    assert_equal(count, alqs.size, "Aliquot count incorrect")
    assert_equal(par_qty, @spc.available_quantity, "Parent #{@spc} quantity not decremented correctly")
    alqs.each do |alq|
      assert_same(@spc.class, alq.class, "Aliquot #{alq}  class incorrect")
      assert_equal(alq_qty, alq.initial_quantity, "Aliquot #{alq}  quantity incorrect")
      assert_not_nil(alq.specimen_characteristics, "Aliquot #{alq} is missing characteristics")
      assert_same(@spc.specimen_characteristics, alq.specimen_characteristics, "Aliquot #{alq} does not share parent characteristics")
    end
    # make a non-aliquot derived specimen
    @spc.derive(:specimen_class => :molecular, :specimen_type => 'DNA')
    # test that only the aliquots are included in the aliquots accessor
    assert_equal(alqs.to_set, @spc.aliquots.to_set, "Aliquots accessor incorrect")
  end

  def test_aliquot_default_quantity
    start_qty = @spc.available_quantity
    count = 2
    expected_qty = start_qty / count
    aliquots = @spc.derive(:count => count)
    assert_equal(0, @spc.available_quantity, "Parent specimen quantity not decremented correctly")
    aliquots.each do |aliquot|
      assert_equal(expected_qty, aliquot.initial_quantity, "Aliquot quantity incorrect")
    end
  end

  def test_withdraw_consent
    # Add the default SCG consent status.
    @spc.specimen_collection_group.add_defaults
    # Withdraw the specimen consent.
    @spc.withdraw_consent
    cts = @spc.consent_tier_statuses.first
    assert_not_nil(cts, "#{@spc} does not have a consent tier status")
    assert_equal('Withdrawn', cts.status, "#{@spc} consent was not withdrawn")
  end
  
  def test_json
    verify_json(@spc)
  end

  # Tests whether a specimen with a position save template does not include the position.
  # The position is saved as a caTissue side-effect by creating a proxy transfer event.
  def test_position_save_template
    defaults.box << @spc
    assert_not_nil(@spc.position, "#{@spc.qp} not added to box")
    # the save template
    tmpl = mock_create_template(@spc)
    assert_nil(tmpl.position, "#{@spc.qp} save template incorrectly includes the position")
  end

  def test_prostate_annotation
    pst = CaTissue::Specimen::Pathology::ProstateSpecimenPathologyAnnotation.new
    pst.merge_attributes(:specimen => @spc)
    grade = CaTissue::Specimen::Pathology::SpecimenHistologicGrade.new
    grade.merge_attributes(:grade => 3, :specimen_base_solid_tissue_pathology_annotation => pst)
    htype = CaTissue::Specimen::Pathology::SpecimenHistologicType.new
    htype.merge_attributes(:type => 3, :specimen_base_solid_tissue_pathology_annotation => pst)
    gleason = CaTissue::Specimen::Pathology::ProstateSpecimenGleasonScore.new
    gleason.merge_attributes(:primary_pattern_score => 3, :secondary_pattern_score => 4, :prostate_specimen_pathology_annotation => pst)
    pth = @spc.pathology.first
    assert_not_nil(pth, "Pathology annotation not added to participant")
    psts = pth.prostate_specimen_pathology_annotations
    assert_not_nil(psts.first, "Prostate annotation not added to participant")
    assert_same(pst, psts.first, "Prostate annotation incorrect")
    assert_same(gleason, pst.gleason_score, "Prostate annotation gleason score incorrect")
    assert_same(grade, pst.histologic_grades.first, "Prostate annotation histologic grades incorrect")
    assert_same(htype, pst.histologic_types.first, "Prostate annotation histologic types incorrect")
  end

  # Verifies that caRuby Tissue is compatible with both the caTissue 1.1.2 and 1.2 Specimen annotation class names. 
  def test_rename
    assert_same(CaTissue::Specimen::Pathology::SpecimenAdditionalFinding, CaTissue::Specimen::Pathology::AdditionalFinding, "caTissue 1.2 annotation class rename unsupported")
    assert_same(CaTissue::Specimen::Pathology::SpecimenDetails, CaTissue::Specimen::Pathology::Details, "caTissue 1.2 annotation class rename unsupported")
    assert_same(CaTissue::Specimen::Pathology::ProstateSpecimenGleasonScore, CaTissue::Specimen::Pathology::GleasonScore, "caTissue 1.2 annotation class rename unsupported")
    assert_same(CaTissue::Specimen::Pathology::SpecimenHistologicGrade, CaTissue::Specimen::Pathology::HistologicGrade, "caTissue 1.2 annotation class rename unsupported")
    assert_same(CaTissue::Specimen::Pathology::SpecimenHistologicType, CaTissue::Specimen::Pathology::HistologicType, "caTissue 1.2 annotation class rename unsupported")
    assert_same(CaTissue::Specimen::Pathology::SpecimenHistologicVariantType, CaTissue::Specimen::Pathology::HistologicVariantType, "caTissue 1.2 annotation class rename unsupported")
    assert_same(CaTissue::Specimen::Pathology::SpecimenInvasion, CaTissue::Specimen::Pathology::Invasion, "caTissue 1.2 annotation class rename unsupported")
  end

  ## DATABASE TEST CASES ##

  def test_simple_save
    verify_save(@spc)

    # verify SCG specimens query
    scg = @spc.specimen_collection_group
    logger.debug { "#{self} verifying #{scg} specimens query..." }
    tmpl = scg.copy(:identifier)
    spcs = database.query(tmpl, :specimens)
    assert_equal(1, spcs.size, "SCG specimen query result count incorrect")
    
    # make a new specimen in the same SCG
    spc2 = @spc.copy(:specimen_class, :specimen_type, :initial_quantity)
    spc2.specimen_collection_group = scg
    logger.debug { "#{self} verifying #{scg} second specimen #{spc2} create..." }
    verify_save(spc2)
    
    # update the specimen
     logger.debug { "#{self} verifying #{@spc} update..." }
     @spc.available_quantity /= 2
     verify_save(@spc)
  end
  
  def test_created_on_save
    crd = @spc.created_on = Date.today << 12 
    @spc.save
    assert_equal(crd.ld, @spc.copy(:identifier).find.created_on.ld, "Created on date was not set in create.")
    crd = @spc.created_on = crd >> 6 
    @spc.save
    assert_equal(crd.ld, @spc.copy(:identifier).find.created_on.ld, "Created on date was not updated.")
  end
  
  def test_characteristics_save
    chr = @spc.specimen_characteristics
    original = chr.tissue_site = 'Lymph node, NOS'
    verify_save(@spc)
    # clear and refetch the characteristics
    @spc.specimen_characteristics.tissue_site = nil
    logger.debug { "#{self.class.qp} verifying the persistent state of the created #{@spc} #{chr} tissue site..." }
    database.find(@spc)
    assert_equal(original, chr.tissue_site, "#{@spc} #{chr} tissue site not updated")
    
    # reset the site and update
    changed = chr.tissue_site = 'Lymph nodes of axilla or arm'
    logger.debug { "#{self.class.qp} updating #{@spc} with #{chr} tissue site changed from #{original} to #{changed}..." }
    verify_save(@spc)
    # clear and refetch the characteristics
    @spc.specimen_characteristics.tissue_site = nil
    logger.debug { "#{self.class.qp} verifying the persistent state of the updated #{@spc} #{chr} tissue site..." }
    database.find(@spc)
    assert_equal(changed, chr.tissue_site, "#{@spc} #{chr} tissue site not updated")
  end
  
  # @quirk JRuby the +verify_save+ commented out in this method fails because a fetched comparison
  #   child Specimen reference is inexplicably swizzled to a different instance which does not
  #   lazy-load the consent tier statuses, resulting in a dependency validation error. This
  #   problem has only been noticed in this test case, and is benign, since the saved Specimen
  #   content is correct.
  def test_derived_consent_update
    # aliquot the specimen
    cspcs = @spc.derive(:count => 2)
    # aliquot the first child
    gcspcs = cspcs.first.derive(:count => 2)
    # derive the first grandchild
    dna = gcspcs.first.derive(:specimen_class => :molecular, :initial_quantity => 20, :specimen_type => 'DNA')
    # save the hierarchy
    @spc.save
    assert_not_nil(dna.identifier, "#{@spc} derived #{dna} not saved.")
    assert_not_nil(dna.consent_tier_statuses.first, "#{@spc} derived #{dna} consent tier status not created.")
    # update the statuses
    @spc.visit_path(:children) { |ref| ref.consent_tier_statuses.first.status = 'Yes' }
    @spc.update
    @spc.visit_path(:children) do |ref|
      cts = ref.consent_tier_statuses.first.copy(:identifier).find.status
      assert_equal('Yes', cts, "#{@spc} derived #{dna} consent tier status not saved.")
    end
  end
  
  def test_nondisposal_specimen_event_save
    # add an event
    ev = CaTissue::SpunEventParameters.new(:specimen => @spc, :duration_in_minutes => 2, :gravity_force => 5)
    verify_save(@spc)
    assert_not_nil(ev.identifier, "#{@spc} event #{ev} not saved")
    # make a nonanticipatory specimen
    spc2 = CaTissue::Specimen.create_specimen(
      :requirement => defaults.specimen_requirement,
      :specimen_collection_group => defaults.specimen_collection_group,
      :initial_quantity => 2.0)
    # add an event to the nonanticipatory specimen
    ev2 = CaTissue::SpunEventParameters.new(:specimen => spc2, :duration_in_minutes => 1, :gravity_force => 3)
    # Save the new specimen
    verify_save(spc2)
    assert_not_nil(ev.identifier, "#{spc2} event #{ev2} not saved")
  end
  
  def test_dispose_save
    @spc.create
    verify_save(CaTissue::Specimen.new(:label => @spc.label).find.dispose)
  end
  
  # Verifies the caRuby Bug #9, #10 and #11 fixes.
  def test_disposal_event_save
    # add an event to the anticipatory specimen
    ev = CaTissue::DisposalEventParameters.new(:specimen => @spc)
    # Save the specimen, which will update the anticipatory specimen
    verify_save(@spc)
    assert_not_nil(ev.identifier, "#{@spc} event #{ev} not saved")
    assert_equal('Closed', @spc.activity_status, "Disposed #{@spc} is not closed")
    # Make a nonanticipatory specimen.
    spc2 = CaTissue::Specimen.create_specimen(
      :requirement => defaults.specimen_requirement,
      :specimen_collection_group => defaults.specimen_collection_group,
      :initial_quantity => 2.0)
    # Dispose the nonanticipatory specimen.
    ev2 = CaTissue::DisposalEventParameters.new(:specimen => spc2)
    # Save the new disposed specimen.
    verify_save(spc2)
    assert_not_nil(ev2.identifier, "#{spc2} event #{ev2} not saved")
  end
 
  # Verifies the work-around for caTissue Bug #159: Update pending Specimen ignores availableQuantity.
  def test_quantity_save
    # reset the available quantity
    @spc.available_quantity = @spc.initial_quantity / 2
    verify_save(@spc)
  end

  # Verifies the CaTissue::Specimen external_identifiers logical dependency work-around.
  def test_eid_save
    verify_save(@spc)
    # add an EID
    CaTissue::ExternalIdentifier.new(:name => Jinx::StringUniquifier.uniquify('Test Name'), :value => 'Test Value', :specimen => @spc)
    # make a new specimen in the same SCG
    spc2 = @spc.copy(:specimen_class, :specimen_type, :initial_quantity, :specimen_collection_group)
    # add an EID
    eid2 = CaTissue::ExternalIdentifier.new(:name => Jinx::StringUniquifier.uniquify('Test Name'), :value => 'Test Value', :specimen => spc2)
    # create the new specimen
    logger.debug { "#{self} creating second EID specimen #{spc2}..." }
    verify_save(spc2)
    # query the Specimen EIDs
    logger.debug { "#{self} verifying #{spc2} EID query..." }
    tmpl = spc2.copy(:identifier)
    tmpl.find
    fetched = tmpl.external_identifiers.first
    assert_not_nil(fetched, "#{tmpl} EID not found in database")
    assert_same(eid2.identifier, fetched.identifier, "Fetched #{tmpl} #{eid2} identifier incorrect")
    # query the Specimen based solely on the alternate search EID criterion
    logger.debug { "#{self} verifying #{spc2} fetch based on EID criterion..." }
    tmpl = spc2.copy(:external_identifiers)
    assert_not_nil(database.find(tmpl), "Specimen not found by external identifier")
    assert_equal(spc2.identifier, tmpl.identifier, "Incorrect specimen found by external identifier")
    # update the specimen to exercise Bug #164 fixed in 1.2
    logger.debug { "#{self} updating second EID specimen #{spc2}..." }
    verify_save(spc2)
  end

  def test_position_save
    defaults.box << @spc
    verify_save(@spc)
    # move the specimen
    @spc.position.location = @spc.position.location.succ
    logger.debug { "#{name} verifing move of #{@spc} to #{@spc.position.location}..." }
    verify_save(@spc)
  end
  
  # Exercises creation of a child specimen.
  def test_derived_create
    # derive a specimen
    drv = @spc.derive(:specimen_class => :molecular, :initial_quantity => 20, :specimen_type => 'DNA')
    logger.debug { "#{name} verifying creation of derived specimen #{@spc}..." }
    # save the derived specimen
    verify_save(drv)
    # verify the derived specimen parent
    assert_same(@spc, drv.parent, "Derived specimen parent incorrect after store")
    # query the derived specimen
    tmpl = CaTissue::Specimen.new(:parent => @spc.class.new(:label => @spc.label))
    verify_query(tmpl) do |children|
      assert_equal(1, children.size, "Parent specimen children count incorrect")
      assert(drv.match_in_owner_scope(children), "Derived specimen not found in parent query result")
    end
  end

  # Exercises aliquot creation.
  def test_aliquot_create
    # make the aliquots
    alqs = @spc.derive(:count => 2)
    # save the specimens
    verify_save(@spc)
    # verify that each aliquot was created
    alqs.each do |alq|
      assert_not_nil(alq.identifier, "#{@spc} aliquot #{alq} not saved")
    end
  end
  
  # Exercises update of an auto-generated child specimen.
  #
  # This test case differs from {#test_derived_create} in that there are critical caTissue code path
  # differences which dictate how the derived object save template is built. See the caTissue
  # alert comment in CaRuby::StoreTemplateBuilder initialize code for details.
  def test_autogenerated_derived_save
    # verify updating an auto-generated derived specimen
    logger.debug { "Verifying updating an auto-generated derived specimen..." }
    # derive a specimen requirement
    rqmt = @spc.requirement.derive(:specimen_class => :molecular, :initial_quantity => 20, :specimen_type => 'DNA')
    # derive the specimen
    drv = @spc.derive(:requirement => rqmt)
    # store the derived specimen
    verify_save(drv)
  end
  
  def test_prostate_annotation_save
    pa = CaTissue::Specimen::Pathology::ProstateSpecimenPathologyAnnotation.new
    pa.specimen = @spc
    grade = CaTissue::Specimen::Pathology::SpecimenHistologicGrade.new
    grade.merge_attributes(
      :grading_system_name => 'Not Specified',
      :grade => 3,
      :specimen_base_solid_tissue_pathology_annotation => pa
    )
    htype = CaTissue::Specimen::Pathology::SpecimenHistologicType.new
    htype.merge_attributes(:type => 3, :specimen_base_solid_tissue_pathology_annotation => pa)
    invn = CaTissue::Specimen::Pathology::SpecimenInvasion.new
    invn.merge_attributes(:lymphatic_invasion => 'Present', :specimen_base_solid_tissue_pathology_annotation => pa)
    gleason = CaTissue::Specimen::Pathology::ProstateSpecimenGleasonScore.new
    gleason.merge_attributes(
      :primary_pattern_score => 3,
      :secondary_pattern_score => 4,
      :prostate_specimen_pathology_annotation => pa
    )
    verify_save(pa)
    assert_not_nil(pa.identifier, "#{@spc} annotation #{pa} not saved")
    assert_not_nil(grade.identifier, "#{@spc} annotation #{grade} not saved")
    assert_not_nil(htype.identifier, "#{@spc} annotation #{htype} not saved")
    assert_not_nil(invn.identifier, "#{@spc} annotation #{invn} not saved")
    assert_not_nil(gleason.identifier, "#{gleason} not saved")
  end

  def test_melanoma_annotation_save
    ma = CaTissue::Specimen::Pathology::MelanomaSpecimenPathologyAnnotation.new
    ma.merge_attributes(
      :specimen => @spc,
      :comments => "Test Comment",
      :depth_of_invasion => 2.0,
      :mitotic_index => "Less than 1 mitotic figure per mm-square",
      :ulceration => "Absent",
      :tumor_regression => "Present involving 75% or more of lesion",
      :tumor_infiltrating_lymphocytes => "Brisk"
    )
    inv = CaTissue::Specimen::Pathology::SpecimenInvasion.new
    inv.merge_attributes(:venous_invasion => 'Present', :specimen_base_solid_tissue_pathology_annotation => ma)
    verify_save(ma)
    assert_not_nil(ma.identifier, "#{ma} not saved")
  end
end