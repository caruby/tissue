module CaTissue
  class Specimen
    module Pathology
      if Java::PathologySpecimen.const_defined?(:SpecimenBaseSolidTissuePathologyAnnotation) then
        resource_import Java::pathology_specimen.SpecimenBaseSolidTissuePathologyAnnotation
        
        class SpecimenBaseSolidTissuePathologyAnnotation
          set_attribute_type(:histologic_grade, CaTissue::Specimen::Pathology::SpecimenHistologicGrade)
          
          set_attribute_type(:histologic_type, CaTissue::Specimen::Pathology::SpecimenHistologicType)
        end
      end
    end
  end
end
