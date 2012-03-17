module CaTissue
  class Specimen
    module Pathology
      class SpecimenBaseSolidTissuePathologyAnnotation
        # @quirk caTissue The SpecimenBaseSolidTissuePathologyAnnotation => SpecimenHistologicGrade collection
        #   property is misnamed as histologicGrade rather than histologicGradeCollection. This misnaming
        #   prevents caRuby from inferring the attribute domain type and inverse. Work-around is to set
        #   these attribute features manually.
        klass = Pathology::SpecimenHistologicGrade rescue Pathology::HistologicGrade
        set_attribute_type(:histologic_grade, klass)
        set_attribute_inverse(:histologic_grade, :specimen_base_solid_tissue_pathology_annotation)

        # @quirk caTissue The SpecimenBaseSolidTissuePathologyAnnotation => SpecimenHistologicType collection
        #   property is misnamed as histologicType rather than histologicTypeCollection. This misnaming
        #   prevents caRuby from inferring the attribute domain type and inverse. Work-around is to set
        #   these attribute features manually.
        klass = Pathology::SpecimenHistologicType rescue Pathology::HistologicType
        set_attribute_type(:histologic_type, klass)
        set_attribute_inverse(:histologic_type, :specimen_base_solid_tissue_pathology_annotation)
      end
    end
  end
end
