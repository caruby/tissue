module CaTissue
  class Specimen
    module Pathology
      if Java::PathologySpecimen.const_defined?(:SpecimenHistologicType) then
        resource_import Java::pathology_specimen.SpecimenHistologicType
        
        class SpecimenHistologicType
          set_attribute_type(:histologic_variant_type, CaTissue::Specimen::Pathology::SpecimenHistologicVariantType)
        end
      end
    end
  end
end
