module CaTissue
  class Specimen
    class Pathology
      begin
        resource_import Java::pathology_specimen.ProstateSpecimenPathologyAnnotation
        const_set(:ProstatePathologyAnnotation, ProstateSpecimenPathologyAnnotation)
        logger.debug { "Aliased the Specimen pathology annotation class ProstateSpecimenPathologyAnnotation to ProstatePathologyAnnotation." }
        class ProstateSpecimenPathologyAnnotation
          # @quirk caTissue the Specimen prostate annotation 1.1 method gleasonScore is renamed to
          #   prostateSpecimenGleasonScore in 1.2. Alias the JRuby wrapper method for backward compatibility.
          if attribute_defined?(:prostate_specimen_gleason_score) then
            add_attribute_aliases(:gleason_score => :prostate_specimen_gleason_score)
          else
            add_attribute_aliases(:prostate_specimen_gleason_score => :gleason_score)
          end
        end
      end
    end
  end
end
