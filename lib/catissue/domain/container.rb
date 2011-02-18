require 'caruby/util/coordinate'
require 'catissue/util/storable'
require 'catissue/util/location'

module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.Container')

  # The +caTissue+ +Container+ domain class wrapper.
  # Each Container subclass is required to implement the {#container_type} method.
  class Container
    include Storable, Resource

    add_attribute_aliases(:position => :located_at_position, :subcontainer_positions => :occupied_positions)

    set_secondary_key_attributes(:name)

    add_attribute_defaults(:activity_status => 'Active', :full => false)

    add_dependent_attribute(:capacity, :logical, :autogenerated)

    # located_at_position is cascaded but not fetched.
    add_dependent_attribute(:located_at_position, :unfetched)

    # caTissue alert - Like SCG, the Container save argument name value is ignored and assigned by caTissue
    # to a different value instead. Therefore, this attribute is marked auto-generated.
    qualify_attribute(:name, :autogenerated)

    # Returns the ContainerType which constrains a Container in its roles as a Storable
    # occupant rather than a Storable holder. {#storable_type} aliases the _container_type_
    # defined by every Container subclass.
    def storable_type
      # can't alias because container_type is defined by subclasses
      container_type
    end

    # @return this Container's ContainerType
    def container_type
      if self.class < Container then raise NotImplementedError.new("Container subclass does not implement the container_type method") end
    end

    def copy(*attributes)
      ctr = super
      ctr.container_type = self.container_type if attributes.empty?
      ctr
    end

    # Returns the ContainerPosition class which this Container can occupy in its role as
    # a Storable.
    def position_class
      CaTissue::ContainerPosition
    end

    # Lazy-initializes this Container's capacity to a copy of the {#storable_type} capacity.
    def capacity
      getCapacity or copy_container_type_capacity
    end

    def bounds
      capacity.bounds if capacity
    end

    # @return the number of rows in this Container
    def rows
      capacity.rows
    end

    # @return the number of columns in this Container
    def columns
      capacity.columns
    end

    # @return this Container's parent container
    def parent
      position and position.parent
    end

    # @return the occupants in this Container's positions.
    # @see 
    def occupants
      all_occupied_positions.wrap { |pos| pos.occupant }
    end

    alias :contents :occupants

    # Returns whether this Container holds the given item or this Container holds
    # a subcontainer which holds the item.
    def include?(item)
      occupants.detect { |occ| occ == item or occ.include?(item) }
    end

    # @return the Specimen occupants
    def specimens
      occupants.filter { |occ| Specimen === occ }
    end

    # @return the Container occupants
    def subcontainers
      occupants.filter { |occ| Container === occ }
    end

    # @return the Containers in this StorageContainer hierarchy
    def subcontainers_in_hierarchy
      @ctr_enum ||= SUBCTR_VISITOR.to_enum(self)
    end

    # @return whether this container or a subcontainer in the hierarchy holds the given object
    def holds?(storable)
      contents.include?(storable) or subcontainers.any? { |ctr| ctr.holds?(storable) }
    end

    # @return true if this Container or a subcontainer in the hierarchy can hold the given storable
    #
    # @see #can_hold_child?
    def can_hold?(storable)
      can_hold_child?(storable) or subcontainers.detect { |ctr| ctr.can_hold?(storable) }
    end

    # @return true if this Container is not full and the {#container_type} can hold the storable as a child
    def can_hold_child?(storable)
      not full? and container_type.can_hold_child?(storable)
    end

    # @return whether this Container and every subcontainer in the hierarchy are full
    def completely_full?
      full? and subcontainers.all? { |ctr| ctr.completely_full? }
    end

    # Returns -1, 0, or 1 if self is contained in, contains or the same as the other
    # Container, resp.
    def <=>(other)
      raise TypeError.new("Can't compare #{qp} to #{other}") unless StorageContainer === self
      return 0 if equal?(other) or (name and name == other.name)
      return 1 if subcontainers.detect { |child| child >= other if StorageContainer === child }
      -1 if other > self
    end

    # @return the occupant at the given zero-based row and column, or nil if none
    def [](column, row)
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
    # @param [CaRuby::Coordinate, nil] coordinate the x-y coordinate to place the item
    # @raise [IndexError] if this Container is full
    # @raise [IndexError] if the row and column are given but exceed the Container bounds
    def add(storable, coordinate=nil)
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
      unless container_type.can_hold_child?(storable) then
        raise TypeError.new("Container #{self} cannot hold an item of the #{storable} type")
      end
    end

    # @param [Coordinate] coordinate the optional location to create
    # @return [Location] the created location
    def create_location(coordinate=nil)
      if coordinate then
        Location.new(:in => self, :at => coordinate)
      else
        first_available_location or raise IndexError.new("Container #{qp} does not have an available location")
      end
    end

    # @return [Location] the next available Location in this container, or nil if no unoccupied
    #   location is available
    def first_available_location
      return if full?
      # look for the first unoccupied location
      occupied = all_occupied_positions.map { |pos| pos.location }.sort
      # find a gap, if one exists, otherwise return the next location
      # after the last occupied location
      current = Location.new(:in => self, :at => Coordinate.new(0, 0))
      occupied.each do |loc|
        break if current < loc
        current.succ!
      end
      current
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