module CaTissue
  # A SCGEventParameters is a SpecimenEventParameters which can be owned by a SpecimenCollectionGroup.
  module SCGEventParameters
    # Returns the SpecimenEventParameters in others which matches this SCGEventParameters in the scope of an owner Specimen or SCG.
    # This method relaxes {CaRuby::Resource#match_in_owner_scope} for a SCGEventParameters that matches any SpecimenEventParameters
    # in others of the same class, since there can be at most one SCGEventParameters of a given class for a given SCG.
    def match_in_owner_scope(others)
      others.detect { |other| minimal_match?(other) }
    end
  end
end