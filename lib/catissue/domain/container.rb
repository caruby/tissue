require 'caruby/util/validation'
require 'caruby/util/coordinate'
require 'catissue/util/storable'
require 'catissue/util/location'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.Container

  # The +caTissue+ +Container+ domain class wrapper.
  # Each Container subclass is required to implement the {#container_type} method.
  class Container
    include Storable

    add_attribute_aliases(:position => :located_at_position, :subcontainer_positions => :occupied_positions)

    set_secondary_key_attributes(:name)

    add_attribute_defaults(:activity_status => 'Active', :full => false)

    # caTissue alert - container capacity was auto-generated in 1.1.2, but is not in 1.2.
    add_dependent_attribute(:capacity)

    # located_at_position is cascaded but not fetched.
    add_dependent_attribute(:located_at_position, :unfetched)

    # caTissue alert - Like SCG, the Container save argument name value is ignored and assigned by caTissue
    # to a different value instead. Therefore, this attribute is marked auto-generated.
    qualify_attribute(:name, :autogenerated)

    # Returns the meta-type which constrains this Container in its role as a {Storable}
    # occupant rather than a {Storable} holder. {#storable_type} aliases the {#container_type}
    # defined by every Container subclass.
    #
    # @return [CaTissue::ContainerType]
    def storable_type
      # can't alias because container_type is defined by subclasses
      container_type
    end

    # @return [CaTissue::ContainerType] this Container's meta-type
    # @raise [NotImplementedError] if this container's Container subclass does not override the
    #   {#container_type} method
    def container_type
      raise NotImplementedError.new("Container subclass does not implement the container_type method")
    end

    # @return [Class] the {CaTissue::ContainerPosition} class which this container can occupy in its role as
    # a {Storable}.
    def position_class
      CaTissue::ContainerPosition
    end

    # Lazy-initializes this Container's capacity to a copy of the {#storable_type} capacity.
    def capacity
      getCapacity or copy_container_type_capacity
    end

    # @return [] the capacity bounds
    def bounds
      capacity.bounds if capacity
    end

    # @return [Integer] the number of rows in this Container
    def rows
      capacity.rows
    end

    # @return  [Integer] the number of columns in this Container
    def columns
      capacity.columns
    end

    # @return [Container, nil] this Container's parent container, if any
    def parent
      position and position.parent
    end

    # @return [<Storable>] the occupants in this Container's positions
    def occupants
      all_occupied_positions.wrap { |pos| pos.occupant }
    end

    alias :contents :occupants

    # @return [Boolean] whether this Container holds the given item or this Container holds
    # a subcontainer which holds the item
    def include?(item)
      occupants.detect { |occ| occ == item or occ.include?(item) }
    end

    # @return [<Specimen>] the direct Specimen occupants
    def specimens
      occupants.filter { |occ| Specimen === occ }
    end

    # @return [<Container>] the direct Container occupants
    def subcontainers
      occupants.filter { |occ| Container === occ }
    end

    # @return [<Container>] the Containers in this StorageContainer hierarchy
    def subcontainers_in_hierarchy
      @ctr_enum ||= SUBCTR_VISITOR.to_enum(self)
    end

    # @return [Boolean] whether this container or a subcontainer in the hierarchy holds the given object
    def holds?(storable)
      contents.include?(storable) or subcontainers.any? { |ctr| ctr.holds?(storable) }
    end

    # @return [Boolean] true if this Container or a subcontainer in the hierarchy can hold the given storable
    #
    # @see #can_hold_child?
    def can_hold?(storable)
      can_hold_child?(storable) or subcontainers.detect { |ctr| ctr.can_hold?(storable) }
    end

    # @return [Boolean] true if this Container is not full and the {#container_type} can hold the storable as a child
    def can_hold_child?(storable)
      not full? and container_type.can_hold_child?(storable)
    end

    # @return  [Boolean] whether this Container and every subcontainer in the hierarchy are full
    def completely_full?
      full? and subcontainers.all? { |ctr| ctr.completely_full? }
    end

    # @return [Storable, nil] the occupant at the given zero-based row and column, or nil if none
    def [](column, row)
      return if column.nil? or row.nil?
      all_occupied_positions.detect_value do |pos|
        return if row < pos.row
        next unless row == pos.row
        pos.occupant if pos.column == column
      end
    end

    # Moves the given Storable from its current Position, if any, to this Container at the optional
    # coordinate. The default coordinate is the first available slot within this Container.
    # The storable Storable position is updated to reflect the new location. Returns self.
    #
    # @param [Storable] storable the item to add
    # @param [CaRuby::Coordinate, <Integer>] coordinate the x-y coordinate to place the item
    # @raise [IndexError] if this Container is full
    # @raise [IndexError] if the row and column are given but exceed the Container bounds
    def add(storable, *coordinate)
      validate_type(storable)
      loc = create_location(coordinate)
      pos = storable.position || storable.position_class.new
      pos.location = loc
      pos.occupant = storable
      pos.holder = self
      logger.debug { "Added #{storable.qp} to #{qp} at #{loc.coordinate}." }
      update_full_flag
      self
    end

    alias :<< :add

    protected

    # Returns the the content collection to which the storable is added. This default returns
    # occupied_positions if storable is a Container, nil otherwise. Subclasses can override.
    #
    # @param [Storable] the item to store
    # @return [<Position>] the occupied positions
    def content_collection_for(storable)
      subcontainer_positions if Container === storable
    end

    private

    # Subcontainer visitor.
    SUBCTR_VISITOR = CaRuby::ReferenceVisitor.new { [:subcontainers] }

    # @param [Storable] the item to store
    # @raise [TypeError] if this container cannot hold the storable
    def validate_type(storable)
      unless container_type then
        raise ValidationError.new("Container #{self} is missing a type")
      end
      unless container_type.can_hold_child?(storable) then
        raise ValidationError.new("Container #{self} cannot hold an item of the #{storable} type #{storable.container_type}")
      end
    end

    # @param coordinate (see #add)
    # @return [Location] the created location
    def create_location(coordinate)
      if coordinate.empty? then
        first_available_location or raise IndexError.new("Container #{qp} does not have an available location")
      else
        if coordinate.size == 1 then coordinate = coordinate.first end
        Location.new(:in => self, :at => coordinate)
      end
    end

    # @return [Location] the next available Location in this container, or nil if no unoccupied
    #   location is available
    def first_available_location
      return if full?
      # look for the first unoccupied location
      occd = all_occupied_positions.map { |pos| pos.location }.sort { |l1, l2| l1.coordinate <=> l2.coordinate }
      # find a gap, if one exists, otherwise return the next location
      # after the last occupied location
      curr = Location.new(:in => self, :at => Coordinate.new(0, 0))
      occd.each do |loc|
        break if curr.coordinate < loc.coordinate
        curr.succ!
      end
      curr
    end

    # Copies this Container's ContainerType capacity, if it exists, to the Container capacity.
    #
    # caTissue alert - this method must be called by subclass initializers. The caTissue API
    # does not make the reasonable assumption that the default Container capacity is the
    # ContainerType capacity.
    #
    # @return [Capacity, nil] the initialized capacity, if any
    def copy_container_type_capacity
      return unless container_type and container_type.capacity
      self.capacity = cpc = container_type.capacity.copy(:rows, :columns)
      logger.debug { "Initialized #{qp} capacity from #{container_type.qp} capacity #{cpc}." }
      update_full_flag
      cpc
    end
    
    def update_full_flag
      self.full = all_occupied_positions.size == rows * columns
    end
  end
end