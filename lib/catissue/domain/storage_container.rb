require 'enumerator'
require 'caruby/util/partial_order'
require 'catissue/util/storage_type_holder'

module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.StorageContainer')

  # The +caTissue+ +StorageContainer+ domain class wrapper.
  class StorageContainer
    include StorageTypeHolder, Resource
    
    # caTissue alert - Bug #64: Some domain collection properties not initialized.
    # Initialize specimen_positions if necessary. 
    #
    # @return [Java::JavaUtil::Set] the positions
    def specimen_positions
      getSpecimenPositionCollection or (self.specimen_positions = Java::JavaUtil::LinkedHashSet.new)
    end

    # Sets the storage type to the given value. Each empty holds collection is initialized
    # from the corresponding StorageType holds collection.
    def storage_type=(value)
      if value and holds_storage_types and holds_storage_types.empty? then
        holds_storage_types.merge!(value.holds_storage_types)
      end
      if value and holds_specimen_array_types and holds_specimen_array_types.empty? then
        holds_specimen_array_types.merge!(value.holds_specimen_array_types)
      end
      if value and holds_specimen_classes and holds_specimen_classes.empty? then
        holds_specimen_classes.merge!(value.holds_specimen_classes)
      end
      setStorageType(value)
    end
    
    def located_at_position=(value)
      setLocatedAtPosition(value)
    end

    add_attribute_aliases(:container_type => :storage_type)

    # Aternative to the inherited secondary key +name+.
    set_alternate_key_attributes(:site, :barcode)

    add_mandatory_attributes(:site, :storage_type)

    qualify_attribute(:collection_protocols, :fetched)

    set_attribute_type(:holds_specimen_array_types, CaTissue::SpecimenArrayType)

    set_attribute_type(:holds_specimen_classes, String)

    set_attribute_type(:holds_storage_types, CaTissue::StorageType)

    def initialize(params=nil)
      super(params)
      # JRuby alert - specimen_positions is sometimes unrecognized unless primed with respond_to? call
      respond_to?(:specimen_positions)
      # work around caTissue Bug #64
      self.specimen_positions ||= Java::JavaUtil::LinkedHashSet.new
    end

    # Corrects the +caTissue+ +occupied_positions+ method to include +specimen_positions+.
    def all_occupied_positions
      subcontainer_positions.union(specimen_positions)
    end

    alias :add_local :add

    # Moves the given Storable from its current Position, if any, to this Container at the optional
    # coordinate. The default coordinate is the first available slot within this Container.
    # The storable Storable position is updated to reflect the new location. Returns self.
    #
    # If there is no coordinate and this container cannot hold the storable type, then the
    # storable is added to a subcontainer which can hold the storable type.
    #
    # @param [Storable] the item to add
    # @param [Coordinate] the storage location (default is first available location)
    # @return [StorageContainer] self
    # @raise [IndexError] if this Container is full
    # @raise [IndexError] if the row and column are given but exceed the Container bounds
    def add(storable, coordinate=nil)
      return add_local(storable, coordinate) if coordinate
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

    # @return a new Container with the given name and type in this Container
    def create_subcontainer(name, type)
      logger.debug { "Creating #{qp} subcontainer of type #{type} with name #{name}..." }
      ctr = type.create_container(:name => name, :site => site)
      self << ctr
      ctr.create
      logger.debug { "Made #{self} subcontainer #{ctr}." }
      ctr
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
    def add_to_existing_container(storable)
      # the subcontainers in column, row sort order
      scs = subcontainers.sort { |sc1, sc2| sc1.position.location <=> sc2.position.location }
      # the first subcontainer that can hold the storable is preferred
      if scs.detect { |ctr| ctr.add_to_existing_container(storable) if StorageContainer === ctr } then
        self
      elsif can_hold_child?(storable) then
        add_local(storable)
      end
    end

    # Creates a subcontainer which holds the given storable. Creates nested subcontainers as necessary.
    #
    # @param @storable (see #add)
    # @return [StorageContainer, nil] self if a subcontainer was created, nil otherwise
    def add_to_new_subcontainer(storable)
      # the subcontainers in column, row sort order
      scs = subcontainers.sort { |sc1, sc2| sc1.position.location <=> sc2.position.location }
      # the first subcontainer that can hold the new subcontainer is preferred
      if scs.detect { |ctr| ctr.add_to_new_subcontainer(storable) if StorageContainer === ctr } then
        self
      elsif not full? then
        create_subcontainer_for(storable)
      end
    end

    # @param [Storable] (see #add)
    # @return whether this StorageContainer is not full and can hold the given item's StorableType
    def can_hold_child?(storable)
      st = storable.storable_type
      not full? and child_types.any? { |ct| CaRuby::Resource.value_equal?(ct, st) }
    end

    private

    # Adds the follwing defaults:
    # * the default child_types are this container's CaTissue::ContainerType child_types.
    # * the default site is the parent container site, if any.
    def add_defaults_local
      super
      if child_types.empty? and container_type and not container_type.child_types.empty? then
        container_type.child_types.each { |type| add_child_type(type) }
      end
      # Although this default is set by the caTissue app, it is good practice to do so here
      # for clarity.
      self.site ||= parent.site if parent
    end

    # @see #add_to_new_subcontainer
    def create_subcontainer_for(storable)
      # the StorageType path to storable
      type_path = type_path_to(storable) || return
      # create a container for each type leading to storable and add it to the parent container
      ctr = type_path.reverse.inject(storable) do |occ, type|
        subctr = type.create_container
        subctr.site = site
        logger.debug { "Created #{qp} #{subctr.container_type.name} subcontainer #{subctr} to hold #{occ}." }
        subctr << occ
      end
      add_local(ctr)
    end

    # Returns a StorageType array from a child StorageType to a descendant StorageType which can
    # hold the given storable, or nil if no such path exists.
    def type_path_to(storable)
      holds_storage_types.detect_value { |type| type.path_to(storable) }
    end

    private

    def out_of_bounds(storable)
      raise IndexError.new("Container #{name} does not have an available position for #{storable}")
    end
  end
end