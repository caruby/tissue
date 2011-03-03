module CaTissue
  # import the Java class
  java_import Java::edu.wustl.catissuecore.domain.ConsentTierStatus

  class ConsentTierStatus
    include Resource

    add_mandatory_attributes(:consent_tier, :status)

    add_attribute_defaults(:status => 'Not Specified')
    
    qualify_attribute(:consent_tier, :fetched)

    # Returns whether this ConsentTierStatus is minimally consistent with the other ConsentTierStatus.
    # This method returns whether the referenced ConsentTier has the same identifer or statement text
    # as the other referenced ConsentTier.
    def minimal_match?(other)
      super and statement_match?(other)
    end

    private

    # Returns true if this ConsentTierStatus ConsentTier is nil, the other ConsentTierStatus ConsentTier is nil,
    # both ConsentTier identifiers are equal, or both ConsentTier statements are equal.
    def statement_match?(other)
      ct = consent_tier
      oct = other.consent_tier
      (ct.nil? or oct.nil?) or (ct.identifier == oct.identifier or ct.statement == oct.statement)
    end
  end
end