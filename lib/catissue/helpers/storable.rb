require 'jinx/helpers/collections'


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

    # Moves this storable from its current {Position}, if any, to the location given by the argument.
    #
    # @param [CaTissue::Container, (CaTissue::Container, Integer, Integer), CaTissue::Location, Hash] args the target container, location, or options
    # @option args [CaTissue::Container] :in the target container
    # @option args [CaRuby::Coordinate, (Integer, Integer)] :at the target coordinates
    # @return [Position] the new position 
    # @see Container#add
    def move_to(*args)
      arg = args.shift
      case arg
        when CaTissue::Container then arg.add(self, *args)
        when CaTissue::Location then
          loc = arg
          loc.container.add(self, loc.coordinate)
        when Hash then
          dest = arg[:in]
          if at.nil? then raise ArgumentError.new("#{self} move_to container :in option not found") end
          coord = arg[:at]
          dest = CaTissue::Location.new(dest, coord) if coord
          move_to(dest)
        else raise ArgumentError.new("Target location is neither a Container nor a Location: #{arg.class.qp}")
      end
      position
    end

    alias :>> :move_to
  end
end