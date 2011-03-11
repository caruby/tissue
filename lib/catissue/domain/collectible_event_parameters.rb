module CaTissue
  # A CollectibleEventParameters is a SpecimenEventParameters which pertains to Specimen
  # or SpecimenCollectionGroup collection at the point of tissue acquisition from the participant
  # or receival at the tissue bank.
  module CollectibleEventParameters
    # Returns the SpecimenEventParameters in others which matches this CollectibleEventParameters in the scope of an owner Specimen or SCG.
    # This method relaxes {CaRuby::Resource#match_in_owner_scope} for a CollectibleEventParameters that matches any SpecimenEventParameters
    # in others of the same class, since there can be at most one CollectibleEventParameters of a given class for a given SCG.
    def match_in_owner_scope(others)
      others.detect { |other| minimal_match?(other) }
    end
  end
end