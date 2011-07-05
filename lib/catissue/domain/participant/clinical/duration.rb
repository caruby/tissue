module CaTissue
  class Participant
    class Clinical
      resource_import Java::clinical_annotation.Duration
      
      class Duration
        add_attribute_aliases(:treatment => :treatment_annotation)
      end
    end
  end
end
