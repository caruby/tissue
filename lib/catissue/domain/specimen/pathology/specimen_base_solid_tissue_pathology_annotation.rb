require File.join(File.dirname(__FILE__), 'specimen_histologic_grade')
require File.join(File.dirname(__FILE__), 'specimen_histologic_type')

module CaTissue
  class Specimen
    class Pathology
      begin
        resource_import Java::pathology_specimen.SpecimenBaseSolidTissuePathologyAnnotation
        const_set(:BaseSolidTissuePathologyAnnotation, SpecimenBaseSolidTissuePathologyAnnotation)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenBaseSolidTissuePathologyAnnotation to BaseSolidTissuePathologyAnnotation." }
      rescue NameError
        logger.debug { "SpecimenBaseSolidTissuePathologyAnnotation pathology annotation class not found; attempting to import the caTissue 1.1 BaseSolidTissuePathologyAnnotation variant..." }
        resource_import Java::pathology_specimen.BaseSolidTissuePathologyAnnotation
        const_set(:SpecimenBaseSolidTissuePathologyAnnotation, BaseSolidTissuePathologyAnnotation)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class BaseSolidTissuePathologyAnnotation class to the renamed 1.2 SpecimenBaseSolidTissuePathologyAnnotation." }
      end
      
      # @quirk caTissue The 1.1 specimen pathology annotation class BaseSolidTissuePathologyAnnotation
      #   is renamed to SpecimenBaseSolidTissuePathologyAnnotation in 1.2.
      #   Alias the Ruby class constant for forward and backaward compatibility.
      # @quirk caTissue The SpecimenBaseSolidTissuePathologyAnnotation => SpecimenHistologicGrade collection
      #   property is misnamed as histologicGrade rather than histologicGradeCollection. This misnaming
      #   prevents caRuby from inferring the attribute domain type and inverse. Work-around is to set
      #   these attribute features manually.
      # @quirk caTissue The SpecimenBaseSolidTissuePathologyAnnotation => SpecimenHistologicType collection
      #   property is misnamed as histologicType rather than histologicTypeCollection. This misnaming
      #   prevents caRuby from inferring the attribute domain type and inverse. Work-around is to set
      #   these attribute features manually.
      class SpecimenBaseSolidTissuePathologyAnnotation
        set_attribute_type(:histologic_grade, CaTissue::Specimen::Pathology::SpecimenHistologicGrade)
        set_attribute_inverse(:histologic_grade, :specimen_base_solid_tissue_pathology_annotation)
        
        set_attribute_type(:histologic_type, CaTissue::Specimen::Pathology::SpecimenHistologicType)
        set_attribute_inverse(:histologic_type, :specimen_base_solid_tissue_pathology_annotation)
      end
    end
  end
end
