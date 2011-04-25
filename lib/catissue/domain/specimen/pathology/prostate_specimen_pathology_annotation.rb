module CaTissue
  class Specimen
    module Pathology
      resource_import Java::pathology_specimen.ProstateSpecimenPathologyAnnotation

      # Augments ProstateSpecimenPathologyAnnotation with a +gleason_score+ alias to the
      # +prostate_specimen_gleason_score+ attribute. 
      class ProstateSpecimenPathologyAnnotation
        if attribute_defined?(:prostate_specimen_gleason_score) then
          alias_attribute(:gleason_score, :prostate_specimen_gleason_score)
        end
      end
    end
  end
end
