require 'catissue/helpers/location'
require 'jinx/helpers/validation'

module CaTissue
  # The Position mix-in encapsulates the location of an occupant in a holder.
  # Classes which include Position are required to implement the column, row, occupant
  # and holder methods. The occupant must be a {Storable}. The holder must be
  # a {Container}.
  module Position
    # @return [Boolean] whether other is an instance of this position's class with the same
    #   occupant and equal location
    #
    # @see Location#==
    def ==(other)
      self.class === other and occupant == other.occupant and location == other.location
    end

    # @return [Coordinate] the read-only coordinate with this AbstractPosition's {Location#row}
    #   and {Location#column}.
    def coordinate
      location.coordinate
    end
    
    # @return [Location] the location of this Position
    def location
      @location ||= Location.new
      # always ensure that the location is consistent with the Java state
      @location.holder = holder
      @location.row = row
      @location.column = column
      @location
    end

    # @param [Location] the location value to set
    def location=(value)
      @location = value || Location.new
      self.holder = @location.holder
      self.row = @location.row
      self.column = @location.column
    end
    
    # @return [Boolean] whether either the column or the row is nil
    def unspecified?
      column.nil? or row.nil?
    end

    # @return [(Integer, Integer)] this Position's zero-based ({Location#column}, {Location#row})
    #   tuple
    def to_a
      [column, row]
    end
    
    # @raise [Jinx::ValidationError] if the holder cannot hold the occupant type
    def validate
      super
      logger.debug { "Validating that #{holder} can hold #{occupant}..." }
      curr_occ = holder[column, row]
      if curr_occ.nil? then
        unless holder.can_hold_child?(occupant) then
          reason = holder.full? ? "it is full" : "the occupant type is not among the supported types #{holder.container_type.child_types.qp}"
          raise Jinx::ValidationError.new("#{holder} cannot hold #{occupant} since #{reason}")
        end
      elsif curr_occ != occupant
        raise Jinx::ValidationError.new("#{holder} cannot hold #{occupant} since the location #{[colum, row]} is already occupied by #{curr_occ}")
      end
    end
  end
end