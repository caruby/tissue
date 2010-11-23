require 'catissue/util/location'

module CaTissue
  # The Position mix-in encapsulates the location of an occupant in a holder.
  # Classes which include Position are required to implement the column, row, occupant
  # and holder methods.
  module Position
    include Comparable

    # @param [Position] other the position to compare
    # @return (see Location#<=>)
    # @raise [ArgumentError] if other is not an instance of this Position's concrete class
    def <=>(other)
      raise ArgumentError.new("Can't compare #{qp} to #{other.qp}") unless self.class === other
      equal?(other) ? 0 : location <=> other.location
    end

    # @return [Boolean] whether other is an instance of this position's class with the same
    #   occupant and equal location
    #
    # @see Location#==
    def ==(other)
      self.class === other and occupant == other.occupant and location == other.location
    end

    # @return [Coordinate] the read-only coordinate with this AbstractPosition's #row and {#column}.
    def coordinate
      location.coordinate
    end
    
    # @return [Location] the location of this Position.
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

    # @return [(Integer, Integer)] this Position's zero-based ({#column}, {#row}) tuple.
    def to_a
      [column, row]
    end
  end
end