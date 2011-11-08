require 'caruby/helpers/collection'
require 'caruby/helpers/partial_order'
require 'catissue/helpers/storage_type_holder'
require 'catissue/domain/hash_code'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.StorageType

  # The StorageType domain class.
  class StorageType < CaTissue::ContainerType
    include StorageTypeHolder, CaRuby::PartialOrder, HashCode

    add_attribute_aliases(:default_temperature => :default_temprature_in_centigrade)

    qualify_attribute(:holds_storage_types, :fetched)

    qualify_attribute(:holds_specimen_array_types, :fetched)

    set_attribute_type(:holds_specimen_array_types, CaTissue::SpecimenArrayType)

    set_attribute_type(:holds_specimen_classes, String)

    set_attribute_type(:holds_storage_types, CaTissue::StorageType)

    # @return StorageContainer
    def container_class
      CaTissue::StorageContainer
    end
    
    alias :add_child :add_child_type
    
    alias :add :add_child_type
    
    alias :<< :add_child_type

    # @return [Boolean] whether this StorageType can hold a child of the given Storable storable type
    def can_hold_child?(storable)
      child_types.include?(storable.storable_type)
    end

    # @return [<StorageType>, nil] the array consisting of types from this type to a descendant
    #   type which can hold the given storable, or nil if no such path exists
    def path_to(storable)
      return [self] if can_hold_child?(storable)
      path = holds_storage_types.detect_value { |child| child.path_to(storable) }
      return path.unshift(self) if path
    end

    # @return [<ContainerType>] the closure of types held by this type, including self
    def closure
      cts = [self]
      child_types.each { |ct| cts.concat(ct.closure) if StorageType === ct }
      cts
    end

    # @quirk caTissue Bug #70: StorageType and non-StorageType are equal.
    #
    # @param other the object to compare
    # @return [Boolean] whether this StorageType has a non-nil name equal to the other name or
    #   is {#equal?} to this StorageType
     def ==(other)
      equal?(other) or (StorageType === other and name and name == other.name)
    end

    alias :eql? :==

    # Returns -1, 0, or 1 if self is contained in, contains or the same as the other
    # StorageType, resp.
    #
    # @param [StorageType] other the type to compare
    # @return [Integer] the order comparison result
    def <=>(other)
      raise TypeError.new("Can't compare #{qp} to #{other}") unless StorageType === self
      return 0 if eql?(other)
      return 1 if holds_storage_types.detect { |child| child >= other }
      -1 if other > self
    end
    
    alias :add_defaults_local :add_container_type_defaults_local
    
    alias :merge_attributes :merge_container_type_attributes
    public :merge_attributes
  end
end