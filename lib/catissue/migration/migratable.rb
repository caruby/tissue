require 'uom'
require 'jinx/migration/migrator'
require 'catissue/annotation/proxy'

module CaTissue
  shims SpecimenCollectionGroup, TissueSpecimen, SpecimenCharacteristics,
    SpecimenEventParameters, CollectibleEventParameters

  class SpecimenCollectionGroup
    @@diagnosis_cv_finder = nil

    # Sets this SpecimenCollectionGroup diagnosis ControlledValueFinder.
    def self.diagnosis_cv_finder=(finder)
      @@diagnosis_cv_finder = finder
    end

    # Returns the diagnosis controlled value as follows:
    # * If CV lookup is disabled, then this method returns value.
    # * Otherwise, if the value is remapped via a configuration remap file,
    #   then this method returns the remapped CV.
    # * Otherwise, if the value is a valid CV, then this method returns value.
    # * Otherwise, this method returns nil.
    #
    # @param [String] value the input diagnosis
    # @return [String] the mapped CV
    def self.diagnosis_controlled_value(value)
      @@diagnosis_cv_finder.nil? ? value : @@diagnosis_cv_finder.controlled_value(value)
    end

    # @return [String] the {diagnosis_controlled_value}
    def migrate_clinical_diagnosis(value, row)
      SpecimenCollectionGroup.diagnosis_controlled_value(value)
    end
  end

  class Specimen
    # Parses the source field as a UOM::Measurement if it is a string.
    # Otherwises, returns the source value.
    def migrate_initial_quantity(value, row)
      standardize_quantity(value)
    end
    
    # Parses the source field as a UOM::Measurement if it is a string.
    # Otherwises, returns the source value.
    def migrate_initial_quantity(value, row)
      standardize_quantity(value)
    end
    
    private
    
    # Parses the source field as a UOM::Measurement if it is a string.
    # Otherwises, returns the source value.
    def standardize_quantity(value)
      # if value is not a string, then use it as is
      return value unless value.is_a?(String)
      # the value has a unit qualifier; parse the measurement.
      # the unit is normalized to the Specimen standard unit.
      value.to_measurement_quantity(standard_unit)
    end
  end

  class SpecimenCharacteristics
    @@site_finder = nil

    # Sets this SpecimenCharacteristics tissue site ControlledValueFinder.
    def self.tissue_site_cv_finder=(finder)
      @@site_finder = finder
    end

    # Returns the tissue site controlled value as follows:
    # * If CV lookup is disabled, then this method returns value.
    # * Otherwise, if the value is remapped via a configuration remap file,
    #   then this method returns the remapped CV.
    # * Otherwise, if the value is a valid CV, then this method returns value.
    # * Otherwise, this method returns nil.
    #
    # @return [String] the caTissue tissue site permissible value
    def self.tissue_site_controlled_value(value)
      @@site_finder.nil? ? value : @@site_finder.controlled_value(value)
    end

    # @return [String] the {tissue_site_controlled_value}
    def migrate_tissue_site(value, row)
      standard_cv_tissue_site(value) or variant_cv_tissue_site(value)
    end

    private

    # Returns the {tissue_site_controlled_value}.
    #
    # @return [String, nil] the caTissue tissue site permissible value, or nil if not found
    def standard_cv_tissue_site(value)
      SpecimenCharacteristics.tissue_site_controlled_value(value) rescue nil
    end

    # Returns the {tissue_site_controlled_value} which adds the 'NOS' suffix to a value
    # without one or removes 'NOS' from a value with the suffix.
    #
    # @return [String] a supported variant of the input value
    # @raise (see ControlledValueFinder#controlled_value)
    def variant_cv_tissue_site(value)
      # try an NOS suffix variation
      variation = value =~ /, NOS$/ ? value[0...-', NOS'.length] : value + ', NOS'
      cv = SpecimenCharacteristics.tissue_site_controlled_value(value)
      logger.warn("Migrator substituted tissue site #{cv} for #{value}.")
      cv
    end
  end

  class SpecimenEventParameters
    # Returns nil by default, since only CollectibleEventParameters have a SCG owner.
    # {CollectibleEventParameters#migrate_specimen_collection_group} overrides this method.
    #
    # @return nil
    def migrate_specimen_collection_group(scg, row)
      nil
    end
  end

  module CollectibleEventParameters
    #@param [SpecimenCollectionGroup] scg the migrated owner SCG
    # @return [SpecimenCollectionGroup] scg
    # @see SpecimenEventParameters#migrate_specimen_collection_group
    def migrate_specimen_collection_group(scg, row)
      # unset the specimen parent if necessary
      self.specimen = nil if specimen and scg
      scg
    end
    
    # Returns the given Specimen spc unless this CollectibleEventParameters already has a SCG owner.
    # A CollectibleEventParameters is preferentially set to a migrated SCG rather than a migrated
    # Specimen.
    #
    # Overrides +Jinx::Migratable.migratable__target_value+ to confer precedence to
    # a SCG over a Specimen when setting this event parameters' owner. If the migrated
    # collection includes both a Specimen and a SCG, then this event parameters
    # +specimen+ reference is ambiguous, but the +specimen_collection_group+ reference
    # is not.
    #
    #@param [Specimen] spc the migrated owner specimen
    # @return [Specimen, nil] spc unless there is already a SCG owner
    def migrate_specimen(spc, row)
      spc unless specimen_collection_group
    end
  end
end