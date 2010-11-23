require 'caruby/migration/uniquify'

module CaTissue
  shims CollectionProtocol, Site, User, Container, ExternalIdentifier, ParticipantMedicalIdentifier,
    CollectionProtocolRegistration, SpecimenCollectionGroup, Specimen

  class CollectionProtocol
    include CaRuby::Migratable::Unique
    
    # Makes this CP's title unique.
    def uniquify
      self.title = self.short_title = uniquify_value(short_title)
    end
  end
  
  class Site
    include CaRuby::Migratable::Unique
    
    # Makes this Site's name unique.
    def uniquify
      self.name = uniquify_value(name)
    end
  end

  class CollectionProtocolRegistration
    include CaRuby::Migratable::Unique
    
    # Makes this CPR's PPI unique.
    def uniquify
      self.protocol_participant_identifier = uniquify_value(protocol_participant_identifier)
    end
  end

  class Container
    include CaRuby::Migratable::Unique
    
    # Makes this Container's name unique.
    def uniquify
      self.name = uniquify_value(name)
    end
  end

  class ContainerType
    include CaRuby::Migratable::Unique
    
    # Makes this ContainerType's name unique.
    def uniquify
      self.name = uniquify_value(name)
    end
  end

  class StorageType
    include CaRuby::Migratable::Unique
    
    # Makes this StorageType and the ContainerTypes which it holds unique.
    def uniquify
      super
      child_types.each { |ct| ct.uniquify if ContainerType === ct }
    end
  end

  class SpecimenCollectionGroup
    include CaRuby::Migratable::Unique
    
    # Makes this SCG's SPN unique.
    def uniquify
      self.surgical_pathology_number = uniquify_value(surgical_pathology_number)
    end
  end

  class Specimen
    include CaRuby::Migratable::Unique
    
    # Makes this Specimen's label unique.
    def uniquify
      self.label = uniquify_value(label.uniquify) if label
    end
  end

  class ExternalIdentifier
    include CaRuby::Migratable::Unique
    
    # Makes this ExternalIdentifier's value unique.
    def uniquify
      self.value = uniquify_value(value)
    end
  end

  class ParticipantMedicalIdentifier
    include CaRuby::Migratable::Unique
    
    # Makes this PMI's MRN unique.
    def uniquify
      self.medical_record_number = uniquify_value(medical_record_number)
    end
  end

  class User
    include CaRuby::Migratable::Unique
    
    # Makes this User's login id and email address unique.
    # The result is in the form _name___suffix_+@test.com+
    # where:
    # * _name_ is the name prefix portion of the original email address
    # * _suffix_ is a unique number
    def uniquify
      email = email_address ||= self.login_name || return
      self.login_name = self.email_address = uniquify_value(email[/[^@]+/]) + '@test.com'
    end
  end
end