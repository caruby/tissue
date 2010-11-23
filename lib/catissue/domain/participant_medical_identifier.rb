

module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.ParticipantMedicalIdentifier')


  # The ParticipantMedicalIdentifier domain class.
  class ParticipantMedicalIdentifier
    include Resource

    # Sets this ParticipantMedicalIdentifier's medical record number to the given value.
    # A Numeric value is converted to a String.
    def medical_record_number=(value)
      value = value.to_s if value
      setMedicalRecordNumber(value)
    end

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
      cp.sites.first if cp and cp.sites.size == 1
    end
  end
end