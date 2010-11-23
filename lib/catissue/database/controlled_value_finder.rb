require 'caruby/util/log'
require 'catissue/database/controlled_values'

module CaTissue
  # Finds attribute controlled values.
  class ControlledValueFinder
    # Creates a new ControlledValueFinder for the given attribute.
    # The optional YAML properties file name maps input values to controlled values.
    def initialize(attribute, file=nil)
      @attribute = attribute
      @remap_hash = load_controlled_value_hash(file)
    end

    # Returns the CV value for the given source value.
    # If the value is remapped, then that value is returned.
    # Otherwise, if the value is a standard CV, then the CV value is returned.
    # Otherwise, a warning message is printed to the log and this method returns nil.
    def controlled_value(value)
      return if value.blank?
      remapped = remapped_controlled_value(value)
      return remapped if remapped
      cv = supported_controlled_value(value)
      logger.warn("#{@attribute} value '#{value}' ignored since it is not a recognized controlled value.") if cv.nil?
      cv.value if cv
    end

    private

    def remapped_controlled_value(value)
      @remap_hash[value]
    end

    def supported_controlled_value(value)
      ControlledValues.instance.find(@attribute, value)
    end

    def load_controlled_value_hash(file)
      return {} unless file and File.exists?(file)
      logger.debug { "Loading controlled value map for #{@attribute} from #{file}..." }
      YAML::load_file(file)
    end
  end
end