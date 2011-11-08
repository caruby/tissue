require 'caruby/helpers/controlled_value'

module CaTissue
  class ControlledValue < CaRuby::ControlledValue

    PUBLIC_ID_ALIAS_MAP = {:tissue_site => 'Tissue_Site_PID', :clinical_diagnosis => 'Clinical_Diagnosis_PID'}

    # Returns the standard public id string for the given public_id_or_alias.
    def self.standard_public_id(public_id_or_alias)
      PUBLIC_ID_ALIAS_MAP[public_id_or_alias.to_sym] or public_id_or_alias.to_s
    end

    attr_accessor :identifier, :public_id

    attr_reader :identifier

    def parent_identifier
      parent.identifier if parent
    end

    def public_id=(public_id_or_alias)
      @public_id = self.class.standard_public_id(public_id_or_alias)
    end

    def to_s
      "#{value}"
    end
  end
end
