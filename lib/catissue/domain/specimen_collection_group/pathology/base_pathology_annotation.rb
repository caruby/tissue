module CaTissue
  class SpecimenCollectionGroup
    class Pathology
      resource_import Java::pathology_scg.BasePathologyAnnotation
      
      # @quirk caTissue The BasePathologyAnnotation => HistologicType collection
      #   property is misnamed as histologicType rather than histologicTypeCollection. This misnaming
      #   prevents caRuby from inferring the attribute domain type and inverse. Work-around is to set
      #   these attribute features manually.
      class BasePathologyAnnotation
        set_attribute_type(:histologic_type, CaTissue::SpecimenCollectionGroup::Pathology::HistologicType)
        set_attribute_inverse(:histologic_type, :base_pathology_annotation)
      end
    end
  end
end
