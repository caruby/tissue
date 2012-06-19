require File.dirname(__FILE__) + '/../helpers/test_case'

# Verifies the Galena caTissue usage examples.
class ExamplesTest < Test::Unit::TestCase
  include Galena::TestCase

  def setup
    super
    @pcl = defaults.protocol
    rqmt = @pcl.events.first.requirements.first
    fixed = CaTissue::Specimen.create_specimen(:requirement => rqmt, :quantity => 1)
    @spc = CaTissue::Specimen.create_specimen(:class => :tissue, :type => 'Frozen Tissue', :quantity => 10)
    @scg = @pcl.add_specimens(fixed, @spc, :participant => CaTissue::Participant.new)
  end

  # Verifies the consent withdrawal example.
  def test_withdraw_consent
    # add a protocol consent tier
    @pcl.consent_tiers << ct = CaTissue::ConsentTier.new(:statement => Jinx::StringUniquifier.uniquify('Test Consent'))
    # add a CPR consent tier response
    @scg.registration.consent_tier_responses << CaTissue::ConsentTierResponse.new(:consent_tier => ct)
    # make the PMI
    mrn = Jinx::UID.generate
    pnt = @scg.registration.participant
    pmi = CaTissue::ParticipantMedicalIdentifier.new(:participant => pnt, :medical_record_number => mrn)
    # save the SCG
    verify_save(@scg)
    # SCG save adds consent statuses
    assert(!@scg.consent_tier_statuses.empty?, "No #{@spc} SCG constent status.")
    logger.debug { "Verifying #{pmi} consent withdrawal..." }
    # Withdraw consent and update each specimen.
    pmi.copy(:medical_record_number).query(:participant, :registrations, :specimen_collection_groups, :specimens).each do |spc|
      spc.withdraw_consent
      spc.save
    end
    # Refetch the SCG and verify the specimen consents.
    @scg.copy(:identifier).find.specimens.each do |spc|
      cts = spc.consent_tier_statuses.first
      assert_not_nil(cts, "#{spc} does not have a consent tier status")
      assert_not_nil(cts.identifier, "#{spc} consent tier status was not created")
      assert_equal('Withdrawn', cts.status, "#{spc} consent was not withdrawn")
    end
  end

  # Verifies the specimen move example.
  def test_move
    # the source box
    src = defaults.box_type.new_container(:site => defaults.hospital, :name => Jinx::StringUniquifier.uniquify('Test Box'))
    src << @spc
    verify_save(@spc)
    # the target box
    tgt = defaults.box_type.new_container(:site => defaults.hospital, :name => Jinx::StringUniquifier.uniquify('Test Box'))
    verify_save(tgt)
    # move the specimen
    logger.debug { "#{self} moving #{@spc} from #{src} to #{tgt}..." }
    spc = @spc.copy(:label).find
    tgt << spc 
    verify_save(spc)
  end
end