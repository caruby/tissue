require 'caruby/helpers/controlled_value'

module CaTissue
  class ControlledValue < CaRuby::ControlledValue
    # @param [String, Symbol] public_id_or_alias the public id value or the
    #   standard alias +:tissue_site+ or +:clinical_diagnosis+
    # @return [String] the standard public id value for the given string or alias
    def self.standard_public_id(public_id_or_alias)
      PID_ALIAS_HASH[public_id_or_alias.to_sym] or public_id_or_alias.to_s
    end

    attr_accessor :identifier

    attr_reader :public_id

    # @return [Integer] the identifier of the parent
    def parent_identifier
      parent.identifier if parent
    end

    # @param public_id_or_alias (see ControlledValue.standard_public_id)
    def public_id=(public_id_or_alias)
      @public_id = self.class.standard_public_id(public_id_or_alias)
    end

    def to_s
      "#{value}"
    end
    
    private

    # The public id symbol => name hash.
    PID_ALIAS_HASH = {:tissue_site => 'Tissue_Site_PID', :clinical_diagnosis => 'Clinical_Diagnosis_PID'}
  end
end
