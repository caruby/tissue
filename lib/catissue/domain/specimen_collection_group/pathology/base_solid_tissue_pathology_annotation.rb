module CaTissue
  class SpecimenCollectionGroup
    class Pathology
      resource_import Java::pathology_scg.BaseSolidTissuePathologyAnnotation
      
      # @quirk caTissue The BaseSolidTissuePathologyAnnotation => HistologicGrade collection
      #   property is misnamed as histologicGrade rather than histologicGradeCollection. This misnaming
      #   prevents caRuby from inferring the attribute domain type and inverse. Work-around is to set
      #   these attribute features manually.
      class BaseSolidTissuePathologyAnnotation
        set_attribute_type(:histologic_grade, CaTissue::SpecimenCollectionGroup::Pathology::HistologicGrade)
        set_attribute_inverse(:histologic_grade, :base_solid_tissue_pathology_annotation)
      end
    end
  end
end
