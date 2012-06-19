require 'jinx/resource/unique'

module CaTissue
  shims CollectionProtocol, CollectionProtocolEvent, Container, ContainerType, StorageType,
    ParticipantMedicalIdentifier, CollectionProtocolRegistration, SpecimenCollectionGroup,
    ExternalIdentifier, User
  
  class CollectionProtocol
    include Jinx::Unique
    
    # Makes this CP's short and long title unique.
    def uniquify
      super
      self.short_title = title
    end
  end

  class CollectionProtocolEvent
    include Jinx::Unique
  end

  class Container
    include Jinx::Unique
    
    # Makes this Container and all of its subcontainers unique.
    def uniquify
      super
      subcontainers.each { |ctr| ctr.uniquify }
    end
  end

  class ContainerType
    include Jinx::Unique
  end

  class StorageType
    def uniquify
      super
      child_container_types.each { |subtype| subtype.uniquify } 
    end
  end

  class ParticipantMedicalIdentifier
    include Jinx::Unique
  end

  class CollectionProtocolRegistration
    include Jinx::Unique
  end

  class SpecimenCollectionGroup
    include Jinx::Unique
  end

  class Specimen
    include Jinx::Unique
  end

  class ExternalIdentifier
    include Jinx::Unique
  end

  class User
    include Jinx::Unique
    
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
