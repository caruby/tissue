require 'caruby/helpers/coordinate'

module CaTissue
  resource_import Java::edu.wustl.catissuecore.domain.Capacity

  class Capacity
    # Sets the first dimension to the specified value. If value is nil, then the dimension is set to default one.
    def one_dimension_capacity=(value)
       # update the bounds as well
      bounds.x = value ||= 1
      setOneDimensionCapacity(value)
    end

    # Sets the second dimension to the specified value. If value is nil, then the dimension is set to default one.
    def two_dimension_capacity=(value)
       # update the bounds as well
      bounds.y = value ||= 1
      setTwoDimensionCapacity(value)
    end

    add_attribute_aliases(:columns => :one_dimension_capacity, :rows => :two_dimension_capacity)

    add_attribute_defaults(:one_dimension_capacity => 1, :two_dimension_capacity => 1)

    add_mandatory_attributes(:one_dimension_capacity, :two_dimension_capacity)

    # Returns the read-only Coordinate with this Capacity's #rows and {#columns}.
    def bounds
      @bounds ||= Coordinate.new(columns, rows)
    end
  end
end