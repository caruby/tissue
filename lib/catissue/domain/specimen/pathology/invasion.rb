module CaTissue
  class Specimen
    module Pathology
      # @quirk caTissue The 1.1.2 class Invasion is renamed to SpecimenInvasion in 1.2.
      #   Alias the Invasion Ruby class to SpecimenInvasion for forward compatibility.
      class Invasion
        Pathology.const_set(:SpecimenInvasion, self)
        logger.debug { "Aliased the caTissue 1.1 Specimen pathology annotation class Invasion class to the renamed 1.2 SpecimenInvasion." }
      end
    end
  end
end
