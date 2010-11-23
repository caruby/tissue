module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.SpecimenArrayType')

  class SpecimenArrayType
    include Resource

    add_mandatory_attributes(:specimen_class, :specimen_types)

    # Returns SpecimenArray.
    def container_class
      CaTissue::SpecimenArray
    end

    # Returns true if Storable is a Specimen and supported by this SpecimenArrayType.
    def can_hold_child?(storable)
      Specimen === storable and storable.specimen_class == specimen_class and specimen_types.include?(storable.specimen_type)
    end
  end
end