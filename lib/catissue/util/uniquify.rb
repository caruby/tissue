require 'caruby/domain/uniquify'

module CaTissue
  class CollectionProtocol
    include CaRuby::Resource::Unique
    
    # Makes this CP's short and long title unique.
    def uniquify
      super
      self.title = short_title
    end
  end

  class Container
    include CaRuby::Resource::Unique
    
    # Makes this Container and all of its subcontainers unique.
    def uniquify
      super
      subcontainers.each { |ctr| ctr.uniquify }
    end
  end

  class ParticipantMedicalIdentifier
    include CaRuby::Resource::Unique
  end

  class CollectionProtocolRegistration
    include CaRuby::Resource::Unique
    
    # Makes this CPR's PPI unique.
    def uniquify
      oldval = protocol_participant_identifier || return
      newval = uniquify_value(oldval)
      self.protocol_participant_identifier = newval
      logger.debug { "Reset #{qp} PPI from #{oldval} to unique value #{newval}." }
    end
  end

  class SpecimenCollectionGroup
    include CaRuby::Resource::Unique
    
    # Makes this SCG's SPN unique.
    def uniquify
      super
      oldval = surgical_pathology_number || return
      newval = uniquify_value(oldval)
      self.surgical_pathology_number = newval
      logger.debug { "Reset #{qp} SPN from #{oldval} to unique value #{newval}." }
    end
  end

  class Specimen
    include CaRuby::Resource::Unique
  end

  class ExternalIdentifier
    include CaRuby::Resource::Unique
    
    # Makes this ExternalIdentifier's value unique.
    def uniquify
      oldval = value || return
      newval = uniquify_value(oldval)
      self.value = newval
      logger.debug { "Reset #{qp} value from #{oldval} to unique value #{newval}." }
    end
  end

  class User
    include CaRuby::Resource::Unique
    
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