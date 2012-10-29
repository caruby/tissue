module CaTissue
  # The ActionEventParameters mix-in adds backward compatibility to the 2.0 event parameter changes.
  module ActionEventParameters
    # Adds the given class to CaTissue for backward compatiblity.
    #
    # @param [Class] klass the ActionEventParameters class
    def self.included(klass)
      # Add the compatibility properties
      unless klass.superclass < ActionEventParameters then
        klass.add_attribute(:specimen, CaTissue::Specimen)
        klass.add_attribute(:specimen_collection_group, CaTissue::SpecimenCollectionGroup)
        klass.add_attribute(:user, CaTissue::User)
        klass.add_attribute(:timestamp, DateTime)
        logger.debug { "Added the #{klass} compatibilty properties specimen_collection_group, specimen and user." }
      end
      CaTissue.const_set(klass.name.demodulize, klass)
      # Resolve the symbol to the SOP class in this CaTissue module namespace.
      logger.debug { "Set CaTissue::#{klass.qp} to the SOP DE class #{klass}." }
    end
    
    # @return [CaTissue::Specimen] the owner +action_application+ specimen value
    def specimen
      action_application.specimen if action_application
    end
    
    # @param [CaTissue::Specimen] specimen the owner +action_application+ specimen
    def specimen=(specimen)
      if specimen then
        if specimen != self.specimen then
          aa = CaTissue::ActionApplication.new(:specimen => specimen)
          self.action_application = aa
        end
      elsif action_application then
        action_application.specimen = nil
        self.action_application = nil
      end
      specimen
    end
    
    # @return [CaTissue::SpecimenCollectionGroup] the owner +action_application+ SCG value
    def specimen_collection_group
      action_application.specimen_collection_group if action_application
    end
    
    alias :specimenCollectionGroup :specimen_collection_group
    
    # @param [CaTissue::SpecimenCollectionGroup] scg the owner +action_application+ SCG
    def specimen_collection_group=(scg)
      if scg then
        if scg != self.specimen_collection_group then
          scg.action_applications << aa = CaTissue::ActionApplication.new
          aa.specimen_collection_group = scg
        end
        self.action_application = aa
      elsif action_application then
        action_application.specimen_collection_group = nil
        self.action_application = nil
      end
      scg
    end
    
    alias :specimenCollectionGroup= :specimen_collection_group=
    
    # @return [CaTissue::User] the owner +action_application+ +performed_by+ value
    def user
      action_application.performed_by if action_application
    end
    
    # Sets the owner +action_application+ +performed_by+ value to the given user.
    #
    # @param [CaTissue::User] user the individual who performed this action
    def user=(user)
      action_application.performed_by = user
    end
    
    # @return [DateTime] the owner +action_application+ +timestamp+ value
    def timestamp
      action_application.timestamp if action_application
    end
    
    # Sets the owner +action_application+ +timestamp+ to the given value.
    #
    # @param [DateTime] ts the time this action was performed
    def timestamp=(ts)
      action_application.timestamp = ts
    end
  end
end
        