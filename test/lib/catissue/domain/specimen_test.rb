require File.join(File.dirname(__FILE__), '..', 'test_case')
require 'test/fixtures/lib/catissue/defaults_test_fixture'
require 'caruby/util/transitive_closure'

class SpecimenTest < Test::Unit::TestCase
  include CaTissue::TestCase

  def setup
    super
    @cpr = defaults.registration
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
    @spc >> dest
    assert_same(dest, @spc.position.container, "Specimen position container incorrect")
    assert(dest.include?(@spc), "Destination #{box.qp} doesn't hold specimen #{@spc.qp}")
    assert(!box.include?(@spc), "Old box #{box.qp} still holds specimen #{@spc.qp}")
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
    assert_equal(par_qty, @spc.available_quantity, "Parent specimen quantity not decremented correctly")
    alqs.each do |alq|
      assert_same(@spc.class, alq.class, "Aliquot class incorrect")
      assert_equal(alq_qty, alq.initial_quantity, "Aliquot quantity incorrect")
      assert_same(@spc.specimen_characteristics, alq.specimen_characteristics, "Aliquot does not share parent characteristics")
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
  
  ## DATABASE TEST CASES ##

  def test_simple_save
    # save the auto-generated specimen
    verify_save(@spc)

    # verify SCG specimens query
    logger.debug { "Verifying SCG specimens query..." }
    scg = @spc.specimen_collection_group
    tmpl = scg.copy(:identifier)
    spcs = database.query(tmpl, :specimens)
    assert_equal(1, spcs.size, "SCG specimen query result count incorrect")
    spc = spcs.first
    spc.class.nondomain_attributes.each do |attr|
      assert_equal(@spc.send(attr), spc.send(attr), "SCG specimen query result #{attr} incorrect")
    end
    
    # make a new specimen in the same SCG
    spc2 = @spc.copy
    spc2.identifier = nil
    spc2.specimen_collection_group = scg
    verify_save(spc2)
  end
  
  # Tests the work-around for caTissue Bug #159: Update pending Specimen ignores availableQuantity.
  def test_quantity_save
    # reset the available quantity
    @spc.available_quantity = @spc.initial_quantity / 2
    verify_save(@spc)
  end

  # Exercises the CaTissue::Specimen external_identifiers logical dependency work-around.
  def test_eid_save
    # add an EID
    eid = CaTissue::ExternalIdentifier.new(:name => 'Test Name'.uniquify, :specimen => @spc, :value => 'Test Value'.uniquify)
    verify_save(@spc)
    # query on the EID
    logger.debug { "Verifying Specimen EID query..." }
    tmpl = @spc.copy(:external_identifiers)
    assert_not_nil(database.find(tmpl), "Specimen not found by external identifier")
    assert_equal(@spc.identifier, tmpl.identifier, "Incorrect specimen found by external identifier")
    # update the specimen to exercise Bug #164
    verify_save(@spc)
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
    # add an event
    CaTissue::SpunEventParameters.new(:specimen => drv, :duration_in_minutes => 2, :gravity_force => 5)
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

  # This test follows caTissue SCG, SEP and Specimen auto-generation as follows:
  # * Create CPR => SCG auto-generated with status Pending, new Specimen, no SEP
  # * Update SCG status to Complete => SEP created
  # * Update SCG SEP
  def test_autogenerated
    # make a new registration
    pnt = CaTissue::Participant.new(:name => 'Test Participant'.uniquify)
    pcl = @cpr.protocol
    cpr = pcl.register(pnt)

    # store the registration without an SCG
    verify_save(cpr)
    # the auto-generated SCG
    scg = cpr.specimen_collection_groups.first
    assert_not_nil(scg, "Missing auto-generated SCG")
    assert_not_nil(scg.identifier, "Auto-generated SCG missing identifier")
    assert_not_nil(scg.collection_event, "Auto-generated SCG missing collection event")
    assert_equal('Pending', scg.collection_status, "Auto-generated SCG status is not Pending")
    # the auto-generated Specimen
    spc = scg.specimens.first
    assert_not_nil(spc, "Auto-generated specimen was not fetched")
    # SEP is not auto-generated
    assert(scg.specimen_event_parameters.empty?, "SEP unexpectedly auto-generated")
    # auto-generated SCG does not have a site, even though it is required for create or update
    assert_nil(scg.collection_site, "SCG collection site unexpectedly auto-generated")

    # update the SCG with site and SEPs
    rcvr = defaults.tissue_bank.coordinator
    site = defaults.specimen_collection_group.collection_site
    scg.merge_attributes(:receiver => rcvr, :collection_site => site).add_defaults
    logger.debug { "#{self.class.qp} updating the auto-generated #{scg.qp}..." }
    scg.update
    # clear and refetch the status
    scg.collection_status = nil
    logger.debug { "#{self.class.qp} refetching the updated #{scg.qp}..." }
    scg.find
    assert_equal('Pending', spc.collection_status, "Auto-generated specimen status is not Pending after update")

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
    assert_equal('Collected', spc.collection_status, "Specimen status not updated")
    assert_equal('Ileum', spc.specimen_characteristics.tissue_site, "Specimen tissue site not updated")

    # update the SCG with complete status
    scg.collection_status = 'Complete'
    logger.debug { "#{self.class.qp} updating the #{scg.qp} collection status #{scg.qp}..." }
    scg.update
    verify_save(scg)
  end
end