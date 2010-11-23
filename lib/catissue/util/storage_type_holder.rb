require 'caruby/util/collection'

module CaTissue
  # The StorageTypeHolder mix-in adds common methods for the StorageType or StorageContainer child type accessors.
  module StorageTypeHolder
    include PartialOrder

    # Returns the {CaTissue::SpecimenArrayType}, {CaTissue::AbstractSpecimen#specimen_class} or {CaTissue::StorageType}
    # children which this StorageTypeHolder can hold.
    def child_types
      @child_types ||= holds_storage_types.union(holds_specimen_classes).union(holds_specimen_array_types)
    end

    # Adds the given subtype to the list of subtypes which this StorageType can hold.
    #
    # @param [CaTissue::StorageType, CaTissue::SpecimenArrayType, String] the subcontainer type or
    #   {CaTissue::AbstractSpecimen#specimen_class} which this StorageType can hold
    # @return [StorageTypeHolder] self
    # @raise [ArgumentError] if the type to add is not a supported parameter
    def add_child_type(type)
      case type
      when CaTissue::StorageType then holds_storage_types << type
      when CaTissue::SpecimenArrayType then holds_specimen_array_types << type
      when String then holds_specimen_classes << type
      else raise ArgumentError.new("Storage type child not supported - #{type}")
      end
      self
    end
  end
end