module CaTissue
  class Participant
    module Clinical
      # @quirk caTissue The TreatmentRegimen DE class has both a +treatmentOrder+ and a +treatmentOrderCollection+
      #   property. caRuby ignores +treatmentOrder+.
      class TreatmentRegimen
        if property_defined?(:treatment_order) and property_defined?(:treatment_orders) then
          remove_attribute(:treatment_order)
        end
      end
    end
  end
end
