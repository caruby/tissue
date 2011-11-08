require 'caruby/helpers/collection'

module CaTissue
  # The StorageTypeHolder mix-in adds common methods for the StorageType or StorageContainer child type accessors.
  module StorageTypeHolder
    include PartialOrder
    
    # @return [StorageType] the allowable child storage types
    def child_storage_types
      holds_storage_types
    end
    
    # @return [String] the allowable child specimen classes
    def child_specimen_classes
      holds_specimen_classes
    end
    
    # @return [StorageType] the allowable child specimen array types
    def child_specimen_array_types
      holds_specimen_array_types
    end

    # Returns the {CaTissue::SpecimenArrayType}, {CaTissue::AbstractSpecimen#specimen_class} or {CaTissue::StorageType}
    # children which this StorageTypeHolder can hold.
    def child_types
      child_storage_types.union(child_specimen_classes).union(child_specimen_array_types)
    end
    
    # Adds the given subtype to the list of subtypes which this StorageType can hold.
    #
    # @param [CaTissue::StorageType, CaTissue::SpecimenArrayType, String] the subcontainer type or
    #   {CaTissue::AbstractSpecimen#specimen_class} which this StorageType can hold
    # @return [StorageTypeHolder] self
    # @raise [ArgumentError] if the type to add is not a supported parameter
    def add_child_type(type)
      case type
        when CaTissue::StorageType then add_storage_type(type)
        when CaTissue::SpecimenArrayType then add_specimen_array_type(type)
        when String then add_specimen_class(type)
        else raise ArgumentError.new("Storage type child not supported - #{type}")
      end
      self
    end
    
    private
    
    # Adds the given storage type to the set of types which can be held.
    #
    # @param type [StorageType] the type to add
    def add_storage_type(type)
      child_storage_types << type
    end
    
    # Adds the given speicmen array type to the set of types which can be held.
    #
    # @param type [SpecimenArrayType] the type to add
    def add_specimen_array_type(type)
      child_specimen_array_types << type
    end    
    
    # Adds the given specimen class to the set of types which can be held.
    #
    # @param type [String] the type to add
    def add_specimen_class(type)
      child_specimen_classes << type
    end
  end
end