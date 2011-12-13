require 'caruby/migration/migrator'
require 'catissue/annotation/proxy'

module CaTissue
  shims SpecimenCollectionGroup, CollectionProtocolRegistration, SpecimenCharacteristics,
    SpecimenEventParameters, CollectionEventParameters, ReceivedEventParameters

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

  class SpecimenCharacteristics
    @@tissue_site_cv_finder = nil

    # Sets this SpecimenCharacteristics tissue site ControlledValueFinder.
    def self.tissue_site_cv_finder=(finder)
      @@tissue_site_cv_finder = finder
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
      @@tissue_site_cv_finder.nil? ? value : @@tissue_site_cv_finder.controlled_value(value)
    end

    # @return [String] the {tissue_site_controlled_value}
    def migrate_tissue_site(value, row)
      standard_cv_tissue_site(value) or variant_cv_tissue_site(value)
    end

    private

    # Returns the {tissue_site_controlled_value}.
    #
    # @return the caTissue tissue site permissible value
    def standard_cv_tissue_site(value)
      SpecimenCharacteristics.tissue_site_controlled_value(value)
    end

    # Returns the {tissue_site_controlled_value} which adds the 'NOS' suffix to a value
    # without one or removes 'NOS' from a value with the suffix.
    #
    # @return the caTissue tissue site permissible value
    def variant_cv_tissue_site(value)
      # try an NOS suffix variation
      variation = value =~ /, NOS$/ ? value[0...-', NOS'.length] : value + ', NOS'
      cv = SpecimenCharacteristics.tissue_site_controlled_value(variation)
      logger.warn("Migrator substituted tissue site #{cv} for #{value}.") if cv
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
    # Overrides +CaRuby::Migratable.migratable__target_value+ to confer precedence to
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