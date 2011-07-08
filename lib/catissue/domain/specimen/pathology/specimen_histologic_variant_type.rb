module CaTissue
  class Specimen
    class Pathology
      begin
        resource_import Java::pathology_specimen.SpecimenHistologicVariantType
        const_set(:HistologicVariantType, SpecimenHistologicVariantType)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenHistologicVariantType to HistologicVariantType." }
      rescue NameError
        logger.debug { "SpecimenHistologicVariantType pathology annotation class not found; attempting to import the caTissue 1.1 HistologicVariantType variant..." }
        resource_import Java::pathology_specimen.HistologicVariantType
        const_set(:SpecimenHistologicVariantType, HistologicVariantType)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class HistologicVariantType class to the renamed 1.2 SpecimenHistologicVariantType." }
      end
      
      # @quirk caTissue The 1.1 class HistologicVariantType is renamed to SpecimenHistologicVariantType in 1.2.
      #   Alias the Ruby class constant for forward and backaward compatibility.
      class SpecimenHistologicVariantType; end
    end
  end
end
