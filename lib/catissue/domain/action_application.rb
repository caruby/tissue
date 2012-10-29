require 'catissue/helpers/action_event_parameters'

module CaTissue
  class ActionApplication
    # The SCG owner.
    attr_accessor :specimen_collection_group
    add_attribute(:specimen_collection_group, CaTissue::SpecimenCollectionGroup)
    
    # The specimen owner.
    attr_accessor :specimen
    add_attribute(:specimen, CaTissue::Specimen)
    
    # The Specimen SOP annotation.
    # For compatiblity, the ActionEventParameter definitions can be in the +domain+ source directory
    # as well as the +domain/action_application/sop+ subdirectory.
    #
    # @quirk caTissue 2.0 The ActionApplication DE API differs from other DEs in having a
    #   1:1 hook -> surrogate association, i.e. there is an
    #   ActionApplication -> ActionApplicationRecordEntry reference property and an inverse
    #   ActionApplicationRecordEntry -> ActionApplication reference property. By contrast,
    #   the Specimen -> SpecimenRecordEntry association is 1:M, with a
    #   Specimen -> SpecimenRecordEntry collection reference property and an inverse
    #   SpecimenRecordEntry -> Specimen reference.
    #
    # @quirk caTissue 2.0 Although ActionApplication has a bi-directional reference to the
    #   ActionApplicationRecordEntry DE surrogate, it is unnecessary to set the
    #   ActionApplicationRecordEntry +actionApplication+ property side of the association.
    #   The 2.0 API example does not set this property.
    add_annotation('SOP',
      :group => 'SpecimenEvents',
      :packages => ['gov.nih.nci.dynext.sop'],
      :definitions => [File.dirname(__FILE__) + '/action_application/sop', File.dirname(__FILE__)],
      :mixin => ActionEventParameters)
    
    # Returns the proxy collection which holds the given target event parameters class.
    #
    # @param [Class] klass the target event parameters class
    # @return [<ActionEventParameters>] the proxy collection which holds the given target class
    def action_event_parameters_for(klass)
      pxy = application_record_entry
      return Array::EMPTY_ARRAY if pxy.nil?
      epa = ActionApplication.all_proxy_event_parameter_attributes.detect_attribute_with_property do |prop|
        klass <= prop.type
      end
      raise ArgumentError.new("#{qp} proxy #{pxy.class.qp} does not reference #{klass.qp}") if epa.nil?
      pxy.send(epa)
    end
    
    # @return [<Resource>] the values of {#all_event_parameter_attributes}
    def all_event_parameters
      pxy = application_record_entry
      return Array::EMPTY_ARRAY if pxy.nil?
      eps = ActionApplication.all_proxy_event_parameter_attributes.transform { |pa| application_record_entry.send(pa) }
      Jinx::Flattener.new(eps)
    end
    
    # @param [Resource] the action event parameters to delete
    # @return [Boolean] whether the action event parameters was deleted
    def delete_event_parameters(ep)
      pxy = application_record_entry
      return false if pxy.nil?
      ActionApplication.all_proxy_event_parameter_attributes.any? do |pa|
        application_record_entry.send(pa).remove(ep)
      end
    end
    
    private
    
    def add_defaults_local
      pxy = application_record_entry
      pxy.activity_status ||= 'Active' if pxy      
    end
    
    # @return [<Symbol>] the RecordEntry integration class attributes whose name ends in +EventParameter+
    #   or +EventParameters+
    def self.all_proxy_event_parameter_attributes
      @ep_attrs ||= ActionApplication::SOP.integration_class.attribute_filter { |prop| prop.type.name =~ /EventParameters?$/ }
    end    
  end
end