module CaTissue
  # This HashCode mix-in overrides the caTissue hashCode and equality test to work around caTissue bugs.
  module HashCode
    # caTissue alert - caTissue hashCode changes with identifier assignment.
    # This leads to ugly cascading errors when used in a Set or Hash.
    #
    # @return [Integer] a unique hash code
    # @see #==
    def hash
      proxy_object_id * 31 + 17
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