module CaTissue
  class Specimen
    module Pathology
      # @quirk caTissue The 1.1.2 class HistologicType is renamed to SpecimenHistologicType in 1.2.
      #   Alias the HistologicType Ruby class to SpecimenHistologicType for forward compatibility.
      class HistologicType
        Pathology.const_set(:SpecimenHistologicType, self)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class HistologicType class to the renamed 1.2 SpecimenHistologicType." }

        # @quirk caTissue The HistologicType => HistologicVariantType collection
        #   property is misnamed as histologicVariantType rather than histologicVariantTypeCollection.
        #   This misnaming prevents caRuby from inferring the attribute domain type and inverse.
        #   Work-around is to set these attribute features manually.
        set_attribute_type(:histologic_variant_type, CaTissue::Specimen::Pathology::HistologicVariantType)
        set_attribute_inverse(:histologic_variant_type, :histologic_type)
      end
    end
  end
end
