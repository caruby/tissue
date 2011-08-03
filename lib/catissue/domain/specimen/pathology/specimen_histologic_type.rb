require File.join(File.dirname(__FILE__), 'specimen_histologic_variant_type')

module CaTissue
  class Specimen
    class Pathology
      # @quirk caTissue The 1.1 class HistologicType is renamed to SpecimenHistologicType in 1.2.
      #   Alias the Ruby class constant for forward and backaward compatibility.
      begin
        resource_import Java::pathology_specimen.SpecimenHistologicType
        const_set(:HistologicType, SpecimenHistologicType)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenHistologicType to HistologicType." }
      rescue NameError
        logger.debug { "SpecimenHistologicType pathology annotation class not found; attempting to import the caTissue 1.1 HistologicType variant..." }
        resource_import Java::pathology_specimen.HistologicType
        const_set(:SpecimenHistologicType, HistologicType)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class HistologicType class to the renamed 1.2 SpecimenHistologicType." }
      end
      
      class SpecimenHistologicType
        # @quirk caTissue The SpecimenHistologicType => SpecimenHistologicVariantType collection
        #   property is misnamed as histologicVariantType rather than histologicVariantTypeCollection.
        #   This misnaming prevents caRuby from inferring the attribute domain type and inverse.
        #   Work-around is to set these attribute features manually.
        set_attribute_type(:histologic_variant_type, CaTissue::Specimen::Pathology::SpecimenHistologicVariantType)
        set_attribute_inverse(:histologic_variant_type, :histologic_type)
      end
    end
  end
end
