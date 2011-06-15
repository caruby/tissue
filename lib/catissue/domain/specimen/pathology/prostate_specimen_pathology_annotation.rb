module CaTissue
  class Specimen
    class Pathology
      # caTissue alert - The 1.1 specimen pathology annotation class ProstatePathologyAnnotation
      # is renamed to ProstateSpecimenPathologyAnnotation in 1.2.
      # Alias the Ruby class constant for forward and backaward compatibility.
      begin
        resource_import Java::pathology_specimen.ProstateSpecimenPathologyAnnotation
        const_set(:ProstatePathologyAnnotation, ProstateSpecimenPathologyAnnotation)
        logger.debug { "Aliased the Specimen pathology annotation class ProstateSpecimenPathologyAnnotation to ProstatePathologyAnnotation." }
        class ProstateSpecimenPathologyAnnotation
          # caTissue alert - the Specimen prostate annotation 1.1 method gleasonScore is renamed to
          # prostateSpecimenGleasonScore in 1.2. Alias the JRuby wrapper method for backward compatibility.
          add_attribute_aliases(:gleason_score => :prostate_specimen_gleason_score)
        end
      rescue NameError
        logger.debug { "ProstateSpecimenPathologyAnnotation pathology annotation class not found; attempting to import the caTissue 1.1 ProstatePathologyAnnotation variant..." }
        resource_import Java::pathology_specimen.ProstatePathologyAnnotation
        const_set(:ProstatePathologyAnnotation, ProstateSpecimenPathologyAnnotation)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class ProstatePathologyAnnotation class to the renamed 1.2 ProstateSpecimenPathologyAnnotation." }
        class ProstateSpecimenPathologyAnnotation
          # caTissue alert - the Specimen prostate annotation 1.1 method gleasonScore is renamed to
          # prostateSpecimenGleasonScore in 1.2. Alias the JRuby wrapper method for backward compatibility.
          add_attribute_aliases(:prostate_specimen_gleason_score => :gleason_score)
        end
      end
    end
  end
end
