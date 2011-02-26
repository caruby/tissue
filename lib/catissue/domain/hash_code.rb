module CaTissue
  # This HashCode mix-in overrides the caTissue hashCode and equality test to work around caTissue bugs.
  module HashCode
    # caTissue alert - caTissue hashCode changes with identifier assignment.
    # This leads to ugly cascading errors when used in a Set or Hash.
    #
    # @return [Integer] a unique hash code
    # @see #==
    def hash
      # JRuby alert - JRuby 1.5 object_id can be a String, e.g. CollectionProtocol_null.
      # Work-around to the work-around is to make a unique object id in this aberrant case.
      @_hc ||= (Object.new.object_id * 31) + 17
    end

    # Returns whether other is of type same type as this object with the same hash as this object.
    #
    # caTissue alert - Bug #70: caTissue equal returns true for class mismatch.
    #
    # @param other the object to compare
    # @return [Boolean] whether the objects are identical
    # @see #hash
    def ==(other)
      equal?(other)
    end

    alias :eql? :equal?
  end
end