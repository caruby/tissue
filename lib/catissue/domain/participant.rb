require 'caruby/helpers/validation'
require 'catissue/resource'
require 'catissue/helpers/person'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.Participant

  # The Participant domain class.
  class Participant
    include Person

    # The convenience Person name aggregate is not a Java property but is added as a transient attribute
    # which is reflected in the saved Java property name subfields.
    add_attribute(:name, CaRuby::Person::Name)

    # @quirk caTissue clinical study is unsupported by 1.1.x caTissue, removed in 1.2.
    if attribute_defined?(:clinical_study_registrations) then remove_attribute(:clinical_study_registrations) end

    add_attribute_aliases(:collection_registrations => :collection_protocol_registrations,
      :registrations => :collection_protocol_registrations,
      :medical_identifiers => :participant_medical_identifiers)

    set_secondary_key_attributes(:social_security_number)

    # Clarification on defaults:
    # * 'Unknown': value is unknown by anybody
    # * 'Unspecified': value is known by somebody, but the data was not communicated to the bank
    #
    # Cf. https://cabig-kc.nci.nih.gov/Biospecimen/forums/viewtopic.php?f=16&t=672&p=2343&e=2343
    add_attribute_defaults(:activity_status => 'Active', :ethnicity => 'Unknown', :gender => 'Unspecified',
      :sex_genotype => 'Unknown', :vital_status => 'Unknown')

    # @quirk caTissue Bug #154: Participant gender is specified by caTissue as optional, but if it is not set then
    #   it appears as Female in the GUI even though it is null in the database.
    add_mandatory_attributes(:activity_status, :gender)

    # @quirk caTissue Participant CPR cascade is simulated in the bizlogic.
    #   See the PMI comment below.
    add_dependent_attribute(:collection_protocol_registrations)

    add_dependent_attribute(:races)

    # @quirk caTissue Participant PMI is fetched but not cascaded. However, the Participant bizlogic
    #   simulates PMI cascade. The bizlogic doesn't document why this is done, but it appears that the
    #   reason is to inject an empty PMI if necessary in order to work around a caTissue query bug
    #   (see merge_attribute comment). At any rate, PMI is marked as cascaded in the caRuby metadata
    #   to reflect the bizlogic simulation. However, this designation should be revisited with each
    #   release, since if the bizlogic hack is removed then caRuby Participant PMI save will break.
    #   In other words, fixing the caTissue bug will break this caRuby work-around.
    add_dependent_attribute(:participant_medical_identifiers)

    # SSN is a key, if present, but is not required.
    qualify_attribute(:social_security_number, :optional)
    
    # The clinicial annotation.
    add_annotation('Clinical', :package => 'clinical_annotation', :service => 'CA')
    
    # Overrides +CaRuby::Mergable.merge_attribute+ to work around the caTissue
    #  bugs described in {CaTissue::Participant.remove_phantom_medical_identifier}.
    def merge_attribute(attribute, newval, matches=nil)
      if attribute == :participant_medical_identifiers and newval then
        CaTissue::Participant.remove_phantom_medical_identifier(newval)
      end
      super
    end

    # @return the SSN if it exists, otherwise the first ParticipantMedicalIdentifier, if any, otherwise nil
    def key
      super or medical_identifiers.first
    end

    # @param [CaTissue::Site] the registration site
    # @param [String] mrn the registration MRN
    # @return [CaTissue::ParticipantMedicalIdentifier] a new PMI which adds this Participant to the site
    #   with the MRN
    def add_mrn(site, mrn)
      CaTissue::ParticipantMedicalIdentifier.new(:participant => self, :site => site, :medical_record_number => mrn)
    end

    # @return [<String>] this Participant's medical record numbers. Each medical record number is site-specific.
    # @see the medical_identifiers attribute for MRN-site associations
    def medical_record_numbers
      medical_identifiers.map { |pmi| pmi.medicalRecordNumber }
    end

    # @return [<CTissue::Specimen>] all specimens collected from this participant
    def specimens
      Flattener.new(registrations.specimens.map { |cpr| cpr.specimens })
    end

    # Returns this Participant's CollectionProtocolRegistration protocols.
    def collection_protocols
      collection_registrations.map { |reg| reg.protocol }.uniq
    end

    # Returns the MRN for this participant. If this Participant does not have exactly one
    # MRN, then this method returns nil. This method is a convenience for the common situation
    # where a participant is enrolled at one site.
    # @return [String] the MRN
    def medical_record_number
      return medical_identifiers.first.medical_record_number if medical_identifiers.size == 1
    end

    # Returns the collection site for which this participant has a MRN. If there is not exactly one
    # such site, then this method returns nil. This method is a convenience for the common situation
    # where a participant is enrolled at one site.
    #
    # @return [CaTissue::Site] the collection site
    def collection_site
      return unless medical_identifiers.size == 1
      site = medical_identifiers.first.site
      return if site.nil?
      site.site_type == Site::SiteType::COLLECTION ? site : nil
    end

    protected

    # @quirk caTissue Specimen auto-generates a phantom PMI.
    #   cf. https://cabig-kc.nci.nih.gov/Biospecimen/forums/viewtopic.php?f=19&t=436&sid=ef98f502fc0ab242781b7759a0eaff36
    #
    # @param [<CaTissue::ParticipantMedicalIdentifier>] pmis the PMIs to clean up
    def self.remove_phantom_medical_identifier(pmis)
      phantom = pmis.detect { |pmi| pmi.medical_record_number.nil? }
      if phantom then
        logger.debug { "Work around caTissue bug by removing the phantom fetched #{phantom.participant.qp} #{phantom.qp}..." }
        # dissociate the participant
        phantom.participant = nil
        # remove the phantom medical identifier
        pmis.delete(phantom)
      end
      pmis
    end

    private

    # Returns the first Medical Record Number qualified by the MRN site, if this exists.
    def alternate_key
      return if medical_identifiers.empty?
      pmi = medical_identifiers.first
      pmi.key if pmi
    end

    # Adds a default Unknown Race, if necessary. Although Race is not strictly mandatory in the caTissue
    # API, setting this default emulates the caTissue UI Add Participant page.
    def add_defaults_local
      super
      # Make a new default Race which references this Participant, if necessary. Setting the Race
      # participant to self automatically adds the Race to this Participant's races collection.
      # The Race name defaults to Unknown.
      if races.empty? then CaTissue::Race.new(:participant => self).add_defaults_recursive end
    end
  end
end