require 'uom'
require 'jinx/migration/migrator'
require 'catissue/database/controlled_values'
require 'catissue/database/controlled_value_finder'
require 'catissue/annotation/proxy'

module CaTissue
  shims SpecimenCollectionGroup, TissueSpecimen, SpecimenCharacteristics,
    SpecimenEventParameters, CollectibleEventParameters

  class SpecimenCollectionGroup
    # @return [String] the diagnosis controlled value
    # @raise [Jinx::MigrationError] if the value is not supported
    def migrate_clinical_diagnosis(value, row)
      cv = standard_cv_diagnosis(value)
      if cv.nil? then
        cv = variant_cv_diagnosis(value)
        if cv then 
          logger.warn("Migrator substituted diagnosis #{cv} for #{value}.")
        else
          raise Jinx::MigrationError.new("#{cv} is not a recognized controlled value.")
        end
      end
      cv
    end
    
    # Enables diagnosis controlled value lookup.
    def self.enable_cv_finder
      @diagnosis_cv_finder ||= ControlledValueFinder.new(:clinical_diagnosis)
    end
    
    private

    # Returns the diagnosis controlled value as follows:
    # * If CV lookup is disabled, then this method returns value.
    # * Otherwise, delegate to the CV finder.
    #
    # @param [String] value the input diagnosis
    # @return [String] the mapped CV
    def self.diagnosis_controlled_value(value)
      @diagnosis_cv_finder.nil? ? value : @diagnosis_cv_finder.controlled_value(value)
    end

    # @return [String, nil] the caTissue diagnosis permissible value, or nil if not found
    def standard_cv_diagnosis(value)
      SpecimenCollectionGroup.diagnosis_controlled_value(value) rescue nil
    end

    # Returns the tissue site which adds the 'NOS' suffix to a value without one or removes
    # 'NOS' from a value with the suffix.
    #
    # @return [String, nil] a supported variant of the input value, or nil if none
    # @raise (see ControlledValueFinder#controlled_value)
    def variant_cv_diagnosise(value)
      # try an NOS suffix variation
      variation = value =~ /, NOS$/ ? value[0...-', NOS'.length] : value + ', NOS'
      SpecimenCollectionGroup.diagnosis_controlled_value(variation) rescue nil
    end
  end

  class Specimen
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
    # Enables tissue site controlled value lookup.
    def self.enable_cv_finder
      @site_finder ||= ControlledValueFinder.new(:tissue_site)
    end

    # @return [String] the tissue site controlled value
    # @raise [Jinx::MigrationError] if the value is not supported
    def migrate_tissue_site(value, row)
      cv = standard_cv_tissue_site(value)
      if cv.nil? then
        cv = variant_cv_tissue_site(value)
        if cv then 
          logger.warn("Migrator substituted tissue site #{cv} for #{value}.")
        else
          raise Jinx::MigrationError.new("#{cv} is not a recognized controlled value.")
        end
      end
      cv
    end

    private

    # Returns the tissue site controlled value as follows:
    # * If CV lookup is disabled, then this method returns value.
    # * Otherwise, delegate to the CV finder.
    #
    # @return [String] the caTissue tissue site permissible value
    def self.tissue_site_controlled_value(value)
      @site_finder.nil? ? value : @site_finder.controlled_value(value)
    end

    # @return [String, nil] the caTissue tissue site permissible value,
    #   or nil if not found
    def standard_cv_tissue_site(value)
      SpecimenCharacteristics.tissue_site_controlled_value(value) rescue nil
    end

    # Returns the tissue site which adds the 'NOS' suffix to a value without one
    # or removes 'NOS' from a value with the suffix.
    #
    # @return [String, nil] a supported variant of the input value, or nil if none
    def variant_cv_tissue_site(value)
      # try an NOS suffix variation
      variation = value =~ /, NOS$/ ? value[0...-', NOS'.length] : value + ', NOS'
      SpecimenCharacteristics.tissue_site_controlled_value(variation) rescue nil
    end
  end

  class SpecimenEventParameters
    # Returns nil by default, since only CollectibleEventParameters have a SCG owner.
    # {CollectibleEventParameters#migrate_specimen_collection_group} overrides this
    # method.
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