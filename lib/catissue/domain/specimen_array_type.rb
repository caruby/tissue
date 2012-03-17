module CaTissue
  class SpecimenArrayType
    add_mandatory_attributes(:specimen_class, :specimen_types)

    # Returns SpecimenArray.
    def container_class
      CaTissue::SpecimenArray
    end

    # Returns true if Storable is a Specimen and supported by this SpecimenArrayType.
    def can_hold_child?(storable)
      Specimen === storable and storable.specimen_class == specimen_class and specimen_types.include?(storable.specimen_type)
    end
    
    alias :add_defaults_local :add_container_type_defaults_local
    
    alias :merge_attributes :merge_container_type_attributes
    public :merge_attributes
  end
end