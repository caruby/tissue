require File.dirname(__FILE__) + '/../helpers/test_case'

# Verifies the Galena caTissue usage examples.
class ExamplesTest < Test::Unit::TestCase
  include Galena::TestCase

  def setup
    super
    @pcl = defaults.protocol
    @pcl.title = @pcl.title = 'Galena CP'.uniquify
    @pnt = CaTissue::Participant.new(:name => 'Test Participant'.uniquify)
    @pnt.add_mrn(defaults.hospital, CaRuby::Uniquifier.qualifier)
    solid = CaTissue::Specimen.create_specimen(:class => :tissue, :type => 'Frozen Tissue', :quantity => 1.0)
    blood = CaTissue::Specimen.create_specimen(:class => :fluid, :type => 'Whole Blood', :quantity => 10)
    rcvr = defaults.tissue_bank.coordinator
    @scg = @pcl.add_specimens(blood, solid, :participant => @pnt, :receiver => rcvr)
  end

  # Verifies the consent withdrawal usage example.
  def test_withdraw_consent
   # add a protocol consent tier
   @pcl.consent_tiers << ct = CaTissue::ConsentTier.new(:statement => 'Test Consent'.uniquify)
   # add a CPR consent tier response
   @scg.registration.consent_tier_responses << CaTissue::ConsentTierResponse.new(:consent_tier => ct)
   # create the SCG
   @scg.create
   logger.debug { "Verifying #{@scg} fluid specimen consent withdrawal..." }
   # the participant MRN
   mrn = @pnt.medical_record_number
   # the template to fetch a PMI for the MRN
   pmi = CaTissue::ParticipantMedicalIdentifier.new(:medical_record_number => mrn)
   # the Specimens for the individual with the MRN
   spcs = pmi.query(:participant, :registrations, :specimen_collection_groups, :specimens).select { |spc| spc.specimen_class == 'Fluid' }
   # withdraw consent and update each fetched specimen
   spcs.each do |spc|
     spc.withdraw_consent(ct)
     verify_save(spc)
   end
  end

  # Verifies the Specimen relabel usage example.
  def test_cp_specimens_relabel
    @scg.create
    @pcl.find.specimens.each do |spc|
      spc.label = 'CP-' + spc.label
      verify_save(spc)
    end
  end

  # Verifies the Specimen relabel usage example.
  def test_site_specimens_relabel
    tb = defaults.tissue_bank
    tbn = tb.name = tb.name.uniquify
    @scg.create
    CaTissue::SpecimenCollectionGroup.new(:site => tb).query(:specimens).each do |spc|
      spc.label = 'CP-' + spc.label
      verify_save(spc)
    end
  end
end