require 'caruby/helpers/coordinate'
require 'caruby/helpers/validation'

module CaTissue
  # A Location is a non-Resource utility class which represents a Container row and column.
  #
  # Location does not capture the occupant; therefore, changing a location coordinate value alone does not
  # change the storage assignment of an occupant.
  class Location
    attr_accessor :container, :coordinate

    alias_attribute(:holder, :container)

    # @param [{Symbol => Object}] params the location fields
    # @option [Integer] params :in the container holding this location
    # @option [Coordinate, (Integer, Integer)] params :at the location coordinate, expressed as either
    #    a Coordinate or a (column, row) array
    # @return the new Location
    def initialize(params=nil)
      Options.validate(params, INIT_OPTS)
      @container = Options.get(:in, params)
      coord = Options.get(:at, params, Coordinate.new)
      # turn an :at Array value into a Coordinate
      if Array === coord and not Coordinate === coord then
        coord = Coordinate.new(*coord) 
      end
      validate_coordinate(coord)
      @coordinate = coord
    end

    # @return this location's zero-based first dimension value
    def column
      @coordinate.x
    end

    # Sets this location's column to the given zero-based value.
    def column=(value)
      @coordinate.x = value
    end

    # @return this location's zero-based second dimension value
    def row
      @coordinate.y
    end

    # Sets this location's row to the given zero-based value.
    def row=(value)
      @coordinate.y = value
    end

    # @return [Boolean] whether other is a Location and has the same content as this Location
    def ==(other)
      container == other.container and coordinate == other.coordinate
    end

    # @return [Location, nil] a new Location at the next slot in this Location's {#container},
    #   or nil if there are no more locations
    def succ
      self.class.new(:in => container, :at => @coordinate).succ! rescue nil
    end

    # Sets this Location to the next slot in this Location's {#container}.
    #
    # @raise [IndexError] if the next slot exceeds the container capacity
    # @return self
    def succ!
      raise IndexError.new("Location #{qp} container not set") unless @container
      raise IndexError.new("Location #{qp} coordinate not set") unless @coordinate
      c = column.succ % @container.capacity.columns
      r = c.zero? ? row.succ : row
      unless r < container.capacity.rows then
        raise IndexError.new("Location #{[c, r].qp} exceeds #{@container} container capacity #{container.capacity.bounds}")
      end
      @coordinate.x = c
      @coordinate.y = r
      self
    end

    def to_s
      ctr_s = @container.print_class_and_id if @container
      coord_s = @coordinate.to_s if @coordinate
      content_s = "{#{ctr_s}#{coord_s}}" if ctr_s or coord_s
      "#{print_class_and_id}{#{content_s}"
    end

    alias :inspect :to_s

    alias :qp :to_s

    private
    
    INIT_OPTS = [:in, :at].to_set
    
    # @param [CaRuby::Coordinate] coord the coordinate to validate
    # @raise [IndexError] if the coordinate exceeds the container bounds
    def validate_coordinate(coord)
      bnds = @container && @container.bounds
      if bnds and coord >= bnds then
        raise IndexError.new("Location #{coord} exceeds container #{@container} dimensions #{bnds}")
      end
    end
  end
end