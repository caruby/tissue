require 'caruby/util/collection'

module CaTissue
  # The Storable mix-in adds methods for a domain class which can be stored and implements
  # the +storable_type+, +position+ and +position_class+ methods.
  module Storable
    # Position is an alias for CaTissue::AbstractPosition.
    Position = CaTissue::AbstractPosition

    # Returns the Container which holds this Storable, or nil if none.
    def container
      position and position.container
    end

    # Moves this Storable from its current Position, if any, to the given container at the optional
    # Coordinate coordinate. Returns the new position.
    #
    # @see Container#add
    def move_to(container_or_location)
      case container_or_location
      when CaTissue::Container then
        container_or_location.add(self)
      when CaTissue::Location then
        loc = container_or_location
        loc.container.add(self, loc.coordinate)
      else
        raise ArgumentError.new("Target location is neither a Container nor a Location: #{container_or_location.class.qp}")
      end
      position
    end

    alias :>> :move_to
  end
end