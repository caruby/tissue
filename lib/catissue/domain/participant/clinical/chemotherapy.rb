module CaTissue
  class Participant
    class Clinical
      begin
        resource_import Java::clinical_annotation.Chemotherapy
      
        # @quirk caTissue The Chemotherapy DE class is not a primary entity with an entity id.
        #   ChemoRXAnnotation is used instead. The purpose of the caTissue Chemotherapy class is unknown,
        #   since it adds nothing to ChemoRXAnnotation.
        class Chemotherapy
          def initialize
            raise AnnotationError.new("The caTissue DE class #{self.class} is deprecated. Please use ChemoRXAnnotation instead.")
          end
        end
      rescue NameError
        # backward compatibility
        Chemotherapy = ChemoRXAnnotation
      end
    end
  end
end
