require 'caruby/util/collection'
require 'caruby/util/partial_order'
require 'catissue/util/storage_type_holder'
require 'catissue/domain/hash_code'

module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.StorageType')

  # The StorageType domain class.
  class StorageType
    include StorageTypeHolder, PartialOrder, Resource, HashCode

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

    # @return whether this StorageType can hold a child of the given Storable storable type
    def can_hold_child?(storable)
      child_types.include?(storable.storable_type)
    end

    # Returns a StorageType array from this StorageType to a descendant StorageType which can
    # hold the given storable, or nil if no such path exists.
    def path_to(storable)
      return [self] if can_hold_child?(storable)
      path = holds_storage_types.detect_value { |child| child.path_to(storable) }
      return path.unshift(self) if path
    end

    # @return the closure of ContainerTypes held by this ContainerType, including self
    def closure
      cts = [self]
      child_types.each { |ct| cts.concat(ct.closure) if StorageType === ct }
      cts
    end

    # @return whether this StorageType has a non-nil name equal to the other name or is {#equal?} to this StorageType
    #
    # This method is a work-around for caTissue Bug #70: StorageType and non-StorageType are equal.
    def ==(other)
      equal?(other) or (StorageType === other and name and name == other.name)
    end

    alias :eql? :==

    # Returns -1, 0, or 1 if self is contained in, contains or the same as the other
    # StorageType, resp.
    def <=>(other)
      raise TypeError.new("Can't compare #{qp} to #{other}") unless StorageType === self
      return 0 if eql?(other)
      return 1 if holds_storage_types.detect { |child| child >= other }
      -1 if other > self
    end
  end
end