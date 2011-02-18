

module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.SpecimenArray')

  class SpecimenArray
    include Resource
    
    # caTissue alert - the superclass Container occupied_positions does not apply to SpecimenArray.
    remove_attribute(:occupied_positions)
 
    # Initializes this instance's child storage types from the given type.
    #
    # @param [<StorageType>] the type to set
    def specimen_array_type=(type)
      setSpecimenArrayType(type)
      unless type.nil? then
        copy_container_type_capacity
      end
      type
    end    
    add_attribute_aliases(:container_type => :specimen_array_type, :contents => :specimen_array_contents)

    set_attribute_type(:new_specimen_array_order_items, CaTissue::SpecimenArrayOrderItem)

    add_dependent_attribute(:new_specimen_array_order_items)

    add_dependent_attribute(:specimen_array_contents)

    # Raises NotImplementedError since caTissue SpecimenArray is broken in important ways
    # described below.
    #
    # caTissue alert - SpecimenArray is a subclass of Container but is a mismatch for Container
    # in two critical ways:
    # * SpecimenArray does not hold subcontainers in Container occupied_positions
    # * the Specimen position cannot be a SpecimenArrayContent
    # * SpecimenArrayContent is not an AbstractPosition, although it should be
    #
    # Thus, SpecimenArray extends Container although it shouldn't and SpecimenArrayContent
    # doesn't extend AbstractPosition although it should.
    def add(storable, coordinate=nil, attribute=nil)
      raise NotImplementedError.new("Adding specimens to a SpecimenArray is not yet supported")
    end
    
    alias :<< :add

    alias :all_occupied_positions :specimen_array_contents
    
    protected
    
    # Returns the contents if storable is a Specimen, nil otherwise.
    def content_collection_for(storable)
      contents if CaTissue::Specimen === storable
    end
  end
end