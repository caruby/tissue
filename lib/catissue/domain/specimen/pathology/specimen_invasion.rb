module CaTissue
  class Specimen
    module Pathology
      # @quirk caTissue The 1.1.2 class Invasion is renamed to SpecimenInvasion in 1.2.
      #   Alias the SpecimenInvasion Ruby class constant to Invasion for backward compatibility.
      class SpecimenInvasion
        Pathology.const_set(:Invasion, self)
        logger.debug { "Aliased the Specimen pathology annotation class SpecimenInvasion to Invasion." }
      end
    end
  end
end
