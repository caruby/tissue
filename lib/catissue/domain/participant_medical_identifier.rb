

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.ParticipantMedicalIdentifier


  # The ParticipantMedicalIdentifier domain class.
  #
  # @quirk caTissue 1.2 PMI method signature is corrupted. Work-around is to explicitly set the attribute type.
  #   Cf. https://cabig-kc.nci.nih.gov/Biospecimen/forums/viewtopic.php?f=19&t=984&sid=773ad8f0bbbfc6e9c9b45ec1bf43a6e9.
  class ParticipantMedicalIdentifier
    # Sets this ParticipantMedicalIdentifier's medical record number to the given value.
    # A Numeric value is converted to a String.
    def medical_record_number=(value)
      value = value.to_s if value
      setMedicalRecordNumber(value)
    end
    
    set_attribute_type(:site, CaTissue::Site)

    set_secondary_key_attributes(:site, :medical_record_number)

    add_mandatory_attributes(:participant)

    private

    # Adds defaults as follows:
    # * The default site is the particiant registration protocol site, if unique.
    def add_defaults_local
      super
      self.site ||= default_site
    end
    
    def default_site
      cprs = participant.registrations if participant
      cp = cprs.first.protocol if cprs and cprs.size == 1
      cp.default_site if cp
    end
  end
end