require File.join(File.dirname(__FILE__), 'specimen_histologic_variant_type')

module CaTissue
  class Specimen
    class Pathology
      # @quirk caTissue The 1.1.2 class HistologicType is renamed to SpecimenHistologicType in 1.2.
      #   Alias the SpecimenHistologicType Ruby class to HistologicType for backward compatibility.
      class SpecimenHistologicType
        Pathology.const_set(:HistologicType, self)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenHistologicType to HistologicType." }

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
