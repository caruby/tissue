require 'uom'

module CaTissue
  # Declare the classes modified for migration.
  shims Participant, TissueSpecimen, SpecimenCollectionGroup

  class Participant
    # Extracts the Participant first name from the +Initials+ input field.
    def migrate_first_name(value, row)
      # The first initial is the first "name".
      value[0, 1]
    end

    # Extracts the Participant last name from the +Initials+ input field.
    #
    # @param [String] value the input initials field
    # @param @param [{Symbol => Object}] row the input row field => value hash
    def migrate_last_name(value, row)
      # The last initial is the last "name".
      value[-1, 1]
    end
  end

  class TissueSpecimen
    # Parses the source field as a UOM::Measurement if it is a string.
    # Otherwises, returns the source value.
    #
    # @param [String, Numeric] value the input quantity field
    # @param @param [{Symbol => Object}] row the input row field => value hash
    def migrate_initial_quantity(value, row)
      # if value is not a string, then use it as is
      return value unless value.is_a?(String)
      # the value has a unit qualifier; parse the measurement.
      # the unit is normalized to the Specimen standard unit.
      value.to_measurement_quantity(standard_unit)
    end
  end

  class SpecimenCollectionGroup
    # @return [Boolean] whether this SCG has a SPN
    def migration_valid?
      not surgical_pathology_number.nil?
    end
  end
end