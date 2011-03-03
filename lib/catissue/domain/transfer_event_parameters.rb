require 'caruby/util/validation'
require 'catissue/util/location'

module CaTissue
  # import the Java class
  java_import Java::edu.wustl.catissuecore.domain.TransferEventParameters

  # The +caTissue+ TransferEventParameters class is augmented with zero-based
  # +from_row+, +from_column+, +to_row+ and +to_column+ methods wrapping the corresponding one-based dimension attributes.
  class TransferEventParameters
    include Resource

    add_attribute_aliases(:from_container => :from_storage_container, :to_container => :to_storage_container)

    # column and row are the zero-offset counterparts of position_dimension_one and position_dimension_two, resp.
    offset_attribute(:from_column => :from_position_dimension_one, :from_row => :from_position_dimension_two,
      :to_column => :to_position_dimension_one, :to_row => :to_position_dimension_two)

    add_mandatory_attributes(:to_container, :to_position_dimension_one, :to_position_dimension_two)
    
    # Returns the from Location.
    def from
      Location.new(:in => from_container, :at => [from_column, from_row]) if from_container
    end

    # Sets the from Location.
    def from=(location)
      if location then
        self.from_container = location.container
        self.from_row = location.row
        self.from_column = location.column
      end
      location
    end

    add_attribute(:from)

    # Returns the to Location.
    def to
      Location.new(:in => to_container, :at => [to_column, to_row]) if to_container
    end

    # Sets the to Location.
    def to=(location)
      if location.nil? then raise ArgumentError.new("Specimen cannot be moved to an empty location") end
      self.to_container = location.container
      self.to_row = location.row
      self.to_column = location.column
    end

    add_attribute(:to)
  end
end