require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'caruby/util/transitive_closure'

class SpecimenTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @spc = defaults.specimen
  end

  def test_requirement_copy
    rqmt = @spc.requirement
    rqmt.value_hash(rqmt.class.nondomain_attributes).each do |attr, value|
      assert_equal(value, @spc.send(attr), "Specimen requirement #{attr} not copied")
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

  # Tests whether a Specimen with a position save template does not include the position.
  # The position is saved as a caTissue side-effect by creating a proxy transfer event.
  def test_position_save_template
    defaults.box << @spc
    assert_not_nil(@spc.position, "#{@spc.qp} not added to box")
    # the save template
    tmpl = mock_create_template(@spc)
    assert_nil(tmpl.position, "#{@spc.qp} save template incorrectly includes the position")
  end

  def test_pathology_annotation
    pths = @spc.prostate_specimen_pathology_annotations
    assert(pths.empty?, "Pathology annotations not empty at start")
    pth = CaTissue::Specimen::Pathology::ProstateSpecimenPathologyAnnotation.new
    pth.merge_attributes(:specimen => @spc)
    grade = histologic_grade_class.new
    grade.merge_attributes(:grade => 3, :specimen_base_solid_tissue_pathology_annotation => pth)
    htype = histologic_type_class.new
    htype.merge_attributes(:type => 3, :specimen_base_solid_tissue_pathology_annotation => pth)
    gleason = gleason_class.new
    gleason.merge_attributes(:primary_pattern_score => 3, :secondary_pattern_score => 4, :prostate_specimen_pathology_annotation => pth)
    assert_not_nil(pths.first, "Pathology annotation not added to participant pths")
    assert_same(pth, pths.first, "Pathology annotation incorrect")
    assert_same(gleason, gleason_score(pth), "Pathology annotation gleason score incorrect")
    assert_same(grade, pth.histologic_grades.first, "Pathology annotation histologic grades incorrect")
    assert_same(htype, pth.histologic_types.first, "Pathology annotation histologic types incorrect")
  end
  
  ## DATABASE TEST CASES ##

  def test_simple_save
    verify_save(@spc)

    # verify SCG specimens query
    logger.debug { "Verifying SCG specimens query..." }
    scg = @spc.specimen_collection_group
    tmpl = scg.copy(:identifier)
    spcs = database.query(tmpl, :specimens)
    assert_equal(1, spcs.size, "SCG specimen query result count incorrect")
    
    # make a new specimen in the same SCG
    spc2 = @spc.copy(:specimen_class, :specimen_type, :initial_quantity)
    spc2.specimen_collection_group = scg
    verify_save(spc2)
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
  
  def test_event_save
    # add an event
    ev = CaTissue::SpunEventParameters.new(:specimen => @spc, :duration_in_minutes => 2, :gravity_force => 5)
    verify_save(@spc)
    assert_not_nil(ev.identifier, "#{@spc} event #{ev} not saved")
  end
  
  # Tests the work-around for caTissue Bug #159: Update pending Specimen ignores availableQuantity.
  def test_quantity_save
    # reset the available quantity
    @spc.available_quantity = @spc.initial_quantity / 2
    verify_save(@spc)
  end

  # Exercises the CaTissue::Specimen external_identifiers logical dependency work-around.
  def test_eid_save
    verify_save(@spc)
    # add an EID
    CaTissue::ExternalIdentifier.new(:name => 'Test Name'.uniquify, :value => 'Test Value'.uniquify, :specimen => @spc)
    # make a new specimen in the same SCG
    spc2 = @spc.copy(:specimen_class, :specimen_type, :initial_quantity, :specimen_collection_group)
    # add an EID
    eid2 = CaTissue::ExternalIdentifier.new(:name => 'Test Name'.uniquify, :value => 'Test Value'.uniquify, :specimen => spc2)
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
   
  def test_events_save
    # add an event
    CaTissue::FrozenEventParameters.new(:specimen => @spc, :freeze_method => 'Cryostat')
    verify_save(@spc)
  end

  def test_position_save
    defaults.box << @spc
    verify_save(@spc)
    # move the specimen
    @spc.position.location = @spc.position.location.succ
    logger.debug { "#{name} verifing move of #{@spc} to #{@spc.position.location}..." }
    verify_save(@spc)
  end
  
  # Exercise creation of a child specimen.
  def test_derived_create
    # verify creating a derived specimen
    logger.debug { "Verifying creating a derived specimen..." }
    # derive a specimen
    drv = @spc.derive(:specimen_class => :molecular, :initial_quantity => 20, :specimen_type => 'DNA')
    # store the derived specimen
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
  
  # Exercise update of an auto-generated child specimen.
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
  
  def test_save_prostate_annotation
    pa = CaTissue::Specimen::Pathology::ProstateSpecimenPathologyAnnotation.new
    pa.specimen = @spc
    grade = histologic_grade_class.new
    grade.merge_attributes(:grading_system_name => 'Not Specified', :grade => 3, :specimen_base_solid_tissue_pathology_annotation => pa)
    htype = histologic_type_class.new
    htype.merge_attributes(:type => 3, :specimen_base_solid_tissue_pathology_annotation => pa)
    invn = invasion_class.new
    invn.merge_attributes(:lymphatic_invasion => 'Present', :specimen_base_solid_tissue_pathology_annotation => pa)
    gleason = gleason_class.new
    gleason.merge_attributes(:primary_pattern_score => 3, :secondary_pattern_score => 4, :prostate_specimen_pathology_annotation => pa)
    verify_save(pa)
    assert_not_nil(pa.identifier, "#{@spc} annotation #{pa} not saved")
    assert_not_nil(grade.identifier, "#{@spc} annotation #{grade} not saved")
    assert_not_nil(htype.identifier, "#{@spc} annotation #{htype} not saved")
    assert_not_nil(invn.identifier, "#{@spc} annotation #{invn} not saved")
    assert_not_nil(gleason.identifier, "#{gleason} not saved")
  end

  def test_save_melanoma_annotation
    ma = CaTissue::Specimen::Pathology::MelanomaSpecimenPathologyAnnotation.new
    ma.merge_attributes(:specimen => @spc, :comments => "Test Comment", :depth_of_invasion => 2.0, :mitotic_index => "Less than 1 mitotic figure per mm-square",
      :ulceration => "Absent", :tumor_regression => "Present involving 75% or more of lesion", :tumor_infiltrating_lymphocytes => "Brisk")
    verify_save(ma)
    assert_not_nil(ma.identifier, "#{ma} not saved")
  end
  
  private
  
  ## caTissue 1.1 compatibility methods ##
  
  def gleason_score(pth)
    pth.respond_to?(:prostate_specimen_gleason_score) ? pth.prostate_specimen_gleason_score : pth.gleason_score
  end
  
  def histologic_grade_class
    @@grade_class ||= begin
      CaTissue::Specimen::Pathology::SpecimenHistologicGrade
    rescue CaRuby::JavaIncludeError
      CaTissue::Specimen::Pathology::HistologicGrade
    end
  end
  
  def invasion_class
    @@invasion_class ||= begin
      CaTissue::Specimen::Pathology::SpecimenInvasion
    rescue CaRuby::JavaIncludeError
      CaTissue::Specimen::Pathology::Invasion
    end
  end
  
  def histologic_type_class
    @@htype_class ||= begin
      CaTissue::Specimen::Pathology::SpecimenHistologicType
    rescue CaRuby::JavaIncludeError
      CaTissue::Specimen::Pathology::HistologicType
    end
  end
  
  def gleason_class
    @@gleason_class ||= begin
      CaTissue::Specimen::Pathology::ProstateSpecimenGleasonScore
    rescue CaRuby::JavaIncludeError
      CaTissue::Specimen::Pathology::GleasonScore
    end
  end
end