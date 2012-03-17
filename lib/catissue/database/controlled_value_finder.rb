require 'catissue/database/controlled_values'

module CaTissue
  class ControlledValueError < RuntimeError; end
  
  # Finds attribute controlled values.
  class ControlledValueFinder
    # Creates a new ControlledValueFinder for the given attribute.
    # The optional YAML properties file name maps input values to controlled values.
    #
    # @param [Symbol] attribute the CV attribute
    def initialize(attribute)
      @attribute = attribute
    end

    # Returns the CV value for the given source value. A case-insensitive lookup
    # is performed on the CV.
    #
    # @param [String, nil] value the CV string value to find
    # @raise [ControlledValueError] if the CV was not found
    # @see ControlledValues#find
    def controlled_value(value)
      return if value.blank?
      ControlledValues.instance.find(@attribute, value) or
        raise ControlledValueError.new("#{@attribute} value '#{value}' is not a recognized controlled value.")
    end
  end
end