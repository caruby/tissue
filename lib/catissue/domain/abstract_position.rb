require 'catissue/helpers/position'

module CaTissue
  # The +caTissue+ AbstractPosition class is augmented with a comparison operator and the
  # zero-based +row+ and +column+ methods wrapping the corresponding one-based dimension
  # attributes. Each AbstractPosition is required to implement the +holder+ and +occupant+
  # methods.
  class AbstractPosition
    include Position

    add_mandatory_attributes(:position_dimension_one, :position_dimension_two)

    # Column and row are the zero-offset counterparts of position_dimension_one and
    # position_dimension_two, resp.
    offset_attribute(:column => :position_dimension_one, :row => :position_dimension_two)

    # add the synthetic {#location} attribute
    add_attribute(:location, Location)
  end
end
