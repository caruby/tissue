require 'jinx/helpers/options'

module CaTissue
  # The caTissue ContainerType domain class wrapper.
  # Each {ContainerType} subclass is required to implement the container_class method.
  #
  # @quirk caTissue the ContainerType and Container class hierarchy is a confusing
  #   olio of entangled relationships. The canonical use case is as follows:
  #   * A Specimen is contained in a box, vial or specimen array.
  #   * A vial or specimen array can also be placed in a box.
  #   * A frozen specimen container is placed on a rack in a freezer.
  #
  #   This conceptual model is implemented in caTissue as follows:
  #   * The specimen collection container type, e.g. +Citrate Vacutainer+, is captured
  #     as a {CaTissue::CollectionEventParameters} +container+ String. There is no separate
  #     collection container instance or container type instance.
  #   * A tissue specimen storage box is captured as a {CaTissue::StorageContainer}
  #     instance constrained to a {CaTissue::StorageType} instance. Boxes with different
  #     types are instances of the same {CaTissue::StorageContainer} class but belong 
  #     to different {CaTissue::StorageType} instances.
  #   * {CaTissue::SpecimenArray} is a {CaTissue::Container} but not a {CaTissue::StorageContainer}.
  #     The specimen array class is {CaTissue::SpecimenArray}, but its type is a
  #     {CaTissue::SpecimenArrayType} instance, which is a {CaTissue::ContainerType} but not
  #     a {CaTissue::StorageType}.
  #   * A rack is a {CaTissue::StorageContainer} instance whose type is a {CaTissue::StorageType}
  #     instance which can hold the box {CaTissue::StorageType}.
  #   * A freezer is a {CaTissue::StorageContainer} instance whose type is a {CaTissue::StorageType}
  #     instance which can hold the rack {CaTissue::StorageType}.
  #   * Each {CaTissue::StorageContainer} belongs to a given {CaTissue::Site}. A child
  #     {CaTissue::StorageContainer} site defaults to its parent container site.
  #     Site consistency is not enforced by caTissue, i.e. it is possible to create
  #     a rack whose site differs from that of its parent freezer and child boxes.
  #   * {CaTissue::SpecimenArray} is not associated to a site.
  #   * The container children are partitioned into three methods for the three different
  #     types and pseudo-types of contained items: {CaTissue::StorageContainer},
  #     {CaTissue::SpecimenArray} and {CaTissue::Specimen#class}.
  #   * {CaTissue::SpecimenArray} holds {CaTissue::SpecimenArrayContent} positions, which
  #     are the functional equivalent of {CaTissue::SpecimenPosition} adapted for specimen
  #     arrays, although {CaTissue::SpecimenArrayContent} is not a {CaTissue::SpecimenPosition}
  #     or even an {CaTissue::AbstractPosition}. {CaTissue::SpecimenPosition} is functionally
  #     a specimen position in a box, whereas {CaTissue::SpecimenArrayContent} is functionally
  #     a specimen position in a specimen array.
  #
  #   The ContainerType/Container mish-mash is partially rationalized in caRuby as follows:
  #   * {CaTissue::StorageType} and {CaTissue::StorageContainer} include the
  #     {CaTissue::StorageTypeHolder} module, which unifies treatment of contained
  #     types.
  #   * Similarly, {CaTissue::AbstractPosition} and {CaTissue::SpecimenArrayContent} include
  #     the {CaTissue::Position} module, which unifies treatment of positions.
  #   * Contained child types are consolidated into {CaTissue::StorageTypeHolder#child_types}.
  #   * Similarly, {CaTissue::StorageContainer} child items are consolidated into
  #     {CaTissue::StorageContainer#child_types}.
  #   * The various container and position classes are augmented with helper methods to
  #     add, move and find specimens and subcontainers. These methods hide the mind-numbing
  #     eccentricity of caTissue specimen storage interaction.
  #   The entire amalgamation is further simplifying by introducing the standard Ruby
  #   container add method {CaTissue::Container::<<}. The only call the caRuby client
  #   needs to make to add a specimen box to a freezer is:
  #     freezer << box
  #   which places the box in the first available rack slot in the freezer, or:
  #     box >> freezer 
  class ContainerType
    add_attribute_aliases(:column_label => :oneDimensionLabel, :row_label => :twoDimensionLabel)

    add_attribute_defaults(:activity_status => 'Active')

    set_secondary_key_attributes(:name)

    add_mandatory_attributes(:activity_status, :capacity, :one_dimension_label, :two_dimension_label)

    # @quirk caTissue although capacity is not marked cascaded in Hibernate, it is created when the
    #   ContainerType is created.
    add_dependent_attribute(:capacity)
    
    # Override default +Jinx::Resource.merge_attributes+ to support the Capacity :rows and +:columns+
    # pseudo-attributes.
    #
    # @quirk JRuby Subclasses do not pick up this class's Resource method overrides.
    #   Specimen picks up the AbstractSpecimen Resource overrides, but ContainerType subclasses do
    #   not pick up ContainerType Resource overrides. Work-around is that each ContainerType
    #   subclass must alias +merge_attributes+ to this method.
    #
    # @param (see Jinx::Mergeable#merge_attributes)
    def merge_attributes(other, attributes=nil, matches=nil, &filter)
      if Hash === other then
        # partition the other hash into the Capacity attributes and ContainerType attributes
        cph, other = other.split { |key, value| key == :rows or key == :columns }
        self.capacity ||= CaTissue::Capacity.new(cph).add_defaults unless cph.empty?
      end
      super
    end
    
    alias :merge_container_type_attributes :merge_attributes
    private :merge_container_type_attributes
    
    # @param [CaTissue::Site] site the site where the candidate containers are located
    # @param opts (see CaRuby::Writer#find)
    # @option (see CaRuby::Writer#find)
    # @return an available container of this ContainerType which is not
    #   {CaTissue::Container#completely_full?}.
    def find_available(site, opts=nil)
      logger.debug { "Finding an available #{site} #{self} container..." }
      find_containers(:site => site).detect { |ctr| not ctr.completely_full? } or
      (new_container(:site => site).create if Options.get(:create, opts))
    end

    # Fetches containers of this ContainerType from the database.
    #
    # @param [<Symbol => Object>] params the optional search attribute => value hash
    # @return the containers of this type which satisfy the search parameters
    def find_containers(params=nil)
      tmpl = new_container(params)
      logger.debug { "Finding #{name} containers..." }
      tmpl.query
    end

    # Returns a new Container instance of this ContainerType with an optional attribute => value hash.
    # The container_type of the new Container is this ContainerType.
    #
    # @param [{Symbol => Object}] vh the attribute => value hash
    # @return [Container] the new container
    def new_container(vh=nil)
      vh ||= {}
      vh[:container_type] = self
      container_class.new(vh)
    end

    private
    
    # Adds an empty capacity and default dimension labels, if necessary.
    # The default +one_dimension_label+ is 'Column' if there is a non-zero dimension capacity, 'Unused' otherwise.
    # The default +two_dimension_label+ is 'Row' if there is a non-zero dimension capacity, 'Unused' otherwise.
    #
    # @quirk JRuby See {#merge_container_type_attributes}. Work-around is that each ContainerType
    #   subclass must alias +add_defaults_local+ to this method.
    def add_defaults_local
      super
      self.capacity ||= Capacity.new.add_defaults
      self.row_label ||= capacity.rows && capacity.rows > 0 ? 'Row' : 'Unused'
      self.column_label ||= capacity.columns && capacity.columns > 0 ? 'Column' : 'Unused'
    end
    
    alias :add_container_type_defaults_local :add_defaults_local
  end
end