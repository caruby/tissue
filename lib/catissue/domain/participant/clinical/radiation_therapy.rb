module CaTissue
  class Participant
    module Clinical
      begin
              # @quirk caTissue The RadiationTherapy DE class is not a primary entity with an entity id.
        #   RadRXAnnotation is used instead. The purpose of the caTissue RadiationTherapy class is unknown,
        #   since it adds nothing to RadRXAnnotation.
        class RadiationTherapy
          def initialize
            raise AnnotationError.new("The caTissue DE class #{self.class} is deprecated. Please use RadRXAnnotation instead.")
          end
        end
      rescue NameError
        # backward compatibility
        RadiationTherapy = RadRXAnnotation
      end
    end
  end
end
