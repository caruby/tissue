require 'enumerator'
require 'caruby/helpers/validation'
require 'caruby/helpers/partial_order'
require 'catissue/helpers/storage_type_holder'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.StorageContainer

  # The +caTissue+ +StorageContainer+ domain class wrapper.
  class StorageContainer < CaTissue::Container
    include StorageTypeHolder
    
    # @quirk caTissue Bug #64: Some domain collection properties not initialized.
    # Initialize specimen_positions if necessary. 
    #
    # @return [Java::JavaUtil::Set] the positions
    def specimen_positions
      getSpecimenPositionCollection or (self.specimen_positions = Java::JavaUtil::LinkedHashSet.new)
    end
 
    # Copies the given container type child types to this container instance child types.
    #
    # @quirk caTissue caTissue API does not initialize the container child types to
    #   the container type child types. This method copies the container type child types
    #   to this container instance before it is created.
    #
    # @param [<StorageType>] type the storage type to set
    def storage_type=(type)
      setStorageType(type)
      copy_child_types(type) if type
      type
    end

    add_attribute_aliases(:container_type => :storage_type)

    # Aternative to the inherited secondary key +name+.
    set_alternate_key_attributes(:site, :barcode)

    add_mandatory_attributes(:storage_type)

    qualify_attribute(:collection_protocols, :fetched)

    set_attribute_type(:holds_specimen_array_types, CaTissue::SpecimenArrayType)

    set_attribute_type(:holds_specimen_classes, String)

    set_attribute_type(:holds_storage_types, CaTissue::StorageType)

    # @quirk caTissue Bug #64 - specimen positions is not initialized to an empty set
    #    in the Java constructor. Initialize it to a +LinkedHashSet+ in caRuby.
    def initialize
      super
      # @quirk JRuby specimen_positions is not recognized until respond_to? is called
      respond_to?(:specimen_positions)
      # work around caTissue Bug #64
      self.specimen_positions ||= Java::JavaUtil::LinkedHashSet.new
    end

    # Corrects the +caTissue+ +occupied_positions+ method to include +specimen_positions+.
    def all_occupied_positions
      subcontainer_positions.union(specimen_positions)
    end

    alias :add_local :add
    private :add_local

    # Adds the given storable to this container. If the storable has a current position, then
    # the storable is moved from that position to this container. The new position is given
    # by the given coordinate, if given to this method.
    #
    # The default coordinate is the first available slot within this Container.
    # If this container cannot hold the storable type, then the storable is added to a
    # subcontainer which can hold the storable type.
    #
    # @example
    #   rack << box #=> places the tissue box on the rack
    #   freezer << box #=> places the tissue box on a rack in the freezer
    #   freezer << specimen #=> places the specimen in the first available box in the freezer
    #
    # @param [Storable] the item to add
    # @param [Coordinate, <Integer>] the storage location (default is first available location)
    # @return [StorageContainer] self
    # @raise [IndexError] if this Container is full
    # @raise [IndexError] if the row and column are given but exceed the Container bounds
    def add(storable, *coordinate)
      return add_local(storable, *coordinate) unless coordinate.empty?
      add_to_existing_container(storable) or add_to_new_subcontainer(storable) or out_of_bounds(storable)
      self
    end

    alias :<< :add
    
    # Finds the container with the given name, or creates a new container
    # of the given type if necessary.
    #
    # @param [String] the container search name
    # @param [CaTissue::StorageContainer] the container type
    # @return a container with the given name
    def find_subcontainer(name, type)
      logger.debug { "Finding box with name #{name}..." }
      ctr = CaTissue::StorageContainer.new(:name => name)
      if ctr.find then
        logger.debug { "Container found: #{ctr}." }
      else
        logger.debug { "Container not found: #{name}." }
        create_subcontainer(name, type)
      end
      box
    end

    # @return [Container] a new container with the given name and type, located in this container
    def create_subcontainer(name, type)
      logger.debug { "Creating #{qp} subcontainer of type #{type} with name #{name}..." }
      ctr = type.new_container(:name => name, :site => site)
      self << ctr
      ctr.create
      logger.debug { "Made #{self} subcontainer #{ctr}." }
      ctr
    end

    # Overrides {Container#can_hold_child?} to detect account for the potential instance-specific
    # {StorageTypeHolder#child_types} override allowed by caTissue.
    #
    # @param [Storable] (see #add)
    # @return [Boolean] whether this container is not full and can hold the given item's
    #   {CaTissue::StorableType}
    def can_hold_child?(storable)
      st = storable.storable_type
      not full? and child_types.any? { |ct| CaRuby::Resource.value_equal?(ct, st) }
    end
    
    protected
    
    # Returns the the content collection to which the storable is added, specimen_positions
    # if storable is a Specimen, container_positions otherwise.
    def content_collection_for(storable)
      CaTissue::Specimen === storable ? specimen_positions : super
    end

    # Adds the given storable to a container within this StorageContainer's hierarchy.
    #
    # @param @storable (see #add)
    # @return [StorageContainer, nil] self if added, nil otherwise
    # @raise [CaRuby::ValidationError] if this container does not have a storage type, or if a circular
    #   containment reference is detected
    def add_to_existing_container(storable)
      if storage_type.nil? then raise CaRuby::ValidationError.new("Cannot add #{storable.qp} to #{qp} with missing storage type") end
      # the subcontainers in column, row sort order
      scs = subcontainers.sort { |sc1, sc2| sc1.position.coordinate <=> sc2.position.coordinate }
      logger.debug { "Looking for a #{self} subcontainer from among #{scs.pp_s} to place #{storable.qp}..." } unless scs.empty?
      # the first subcontainer that can hold the storable is preferred
      sc = scs.detect do |sc|
        # Check for circular reference. This occurred as a result of the caTissue bug described
        # in CaTissue::Database#query_object. The work-around circumvents the bug for now, but
        # it doesn't hurt to check again.
        if identifier and sc.identifier == identifier then
          raise CaRuby::ValidationError.new("#{self} has a circular containment reference to subcontainer #{sc}")
        end
        # No circular reference; add to subcontainer if possible
        sc.add_to_existing_container(storable) if StorageContainer === sc
      end
      if sc then
        logger.debug { "#{self} subcontainer #{sc} stored #{storable.qp}." }
        self
      elsif can_hold_child?(storable) then
        logger.debug { "#{self} can hold #{storable.qp}." }
        add_local(storable)
      else
        logger.debug { "Neither #{self} of type #{storage_type.name} nor its subcontainers can hold #{storable.qp}." }
        nil
      end
    end

    # Creates a subcontainer which holds the given storable. Creates nested subcontainers as necessary.
    #
    #   @param @storable (see #add)
    # @return [StorageContainer, nil] self if a subcontainer was created, nil otherwise
    def add_to_new_subcontainer(storable)
      # the subcontainers in column, row sort order
      scs = subcontainers.sort { |sc1, sc2| sc1.position.coordinate <=> sc2.position.coordinate }
      logger.debug { "Looking for a #{self} subcontainer #{scs} to place a new #{storable.qp} container..." } unless scs.empty?
      # the first subcontainer that can hold the new subcontainer is preferred
      sc = scs.detect { |sc| sc.add_to_new_subcontainer(storable) if StorageContainer === sc }
      if sc then
        logger.debug { "#{self} subcontainer #{sc} stored #{storable.qp}." }
        self
      elsif not full? then
        logger.debug { "Creating #{self} of type #{storage_type} subcontainer to hold #{storable.qp}..." }
        create_subcontainer_for(storable)
      end
    end

    def child_types
      holds_storage_types.union(holds_specimen_classes).union(holds_specimen_array_types)
    end
    
    private
    
    # Copies the other child types into this container's child types.
    #
    # @param [StorageTypeHolder] other the source child type holder
    # @see #storage_type=
    def copy_child_types(other)
      child_storage_types.merge!(other.child_storage_types)
      child_specimen_array_types.merge!(other.child_specimen_array_types)
      child_specimen_classes.merge!(other.child_specimen_classes)
    end
    
    # Adds the following defaults:
    # * the default site is the parent container site, if any
    # * the default capacity is copied from the storage type
    #
    # @quirk caTissue caTissue 1.1.2 container create inferred the default container capacity from the
    #   storage type. caTissue 1.2 container create does not make a default capacity. Work-around is to
    #   emulate 1.1.2 behavior by making the default capacity.
    def add_defaults_local
      super
      # Although this default is set by the caTissue app, it is good practice to do so here
      # for clarity.
      self.site ||= parent.site if parent
      self.capacity ||= create_default_capacity
    end
    
    def create_default_capacity
      stype = storage_type || return
      cap = stype.capacity.copy
      logger.debug { "Made #{qp} default capacity #{cap}." }
      cap
    end

    # @see #add_to_new_subcontainer
    def create_subcontainer_for(storable)
      # the StorageType path to storable
      type_path = type_path_to(storable) || return
      # create a container for each type leading to storable and add it to the parent container
      sc = type_path.reverse.inject(storable) do |occ, type|
        ctr = type.new_container
        ctr.site = site
        logger.debug { "Created #{qp} #{ctr.container_type.name} subcontainer #{ctr} to hold #{occ}." }
        ctr << occ
      end
      logger.debug { "Adding #{qp} subcontainer #{sc.qp} with stored #{storable.qp}." }
      add_local(sc)
    end

    # Returns a StorageType array from a child StorageType to a descendant StorageType which can
    # hold the given storable, or nil if no such path exists.
    #
    # @param [Storable] the domain object to store in this container
    # @return [<StorageType>] the {StorageType}s leading from this container to the storable holder
    def type_path_to(storable)
      holds_storage_types.detect_value { |type| type.path_to(storable) }
    end

    # Adds the given storage type to the set of types which can be held.
    #
    # @param type [StorageType] the type to add
    def add_storage_type(type)
      storage_types << type
    end    
    
    # Adds the given speicmen array type to the set of types which can be held.
    #
    # @param type [SpecimenArrayType] the type to add
    def add_specimen_array_type(type)
      storage_types << type
    end    
    
    # Adds the given specimen class to the set of types which can be held.
    #
    # @param type [String] the type to add
    def add_specimen_class(type)
      storage_types << type
    end
    
    def out_of_bounds(storable)
      raise IndexError.new("Container #{name} does not have an available position for #{storable}")
    end
  end
end