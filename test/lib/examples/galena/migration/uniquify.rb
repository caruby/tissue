require 'caruby/util/inflector'
require 'caruby/migration/migratable'
require 'galena/seed/defaults'

module CaTissue
  # Augment the classes below with sufficient content to pass the create mandatory attribute validation.
  #  This simulates an existing administrative object for testing purposes.
  shims CollectionProtocol, CollectionProtocolEvent, Site, SpecimenPosition, User
  
  class CollectionProtocol
    # Augments {CaRuby::Migratable#migrate} for the Galena example by adding the following defaults:
    # * the CP principal_investigator defaults to the {Galena::Seed::Defaults#protocol} PI
    # * if the sites is empty, then the {Galena::Seed::Defaults#tissue_bank} is added
    #   to the CP sites
    #
    # @param (see CaRuby::Migratable#migrate)
    def migrate(row, migrated)
      super
      self.principal_investigator ||= Galena::Seed.defaults.protocol.principal_investigator
      sites << Galena::Seed.defaults.tissue_bank if sites.empty?
    end
  end
  
  class CollectionProtocolEvent
    # Augments {CaRuby::Migratable#migrate} for the example by adding the following defaults:
    # * create a {CaTissue::TissueSpecimenRequirement}
    #
    # @param (see CaRuby::Migratable#migrate)
    def migrate(row, migrated)
      super
      CaTissue::TissueSpecimenRequirement.new(:collection_event => self)
    end
  end

  class Site
    # Augments {CaRuby::Migratable#migrate} for the example by merging the content of the
    # {Galena::Seed::Defaults} site which matches on this Site's name, if any.
    #
    # @param (see CaRuby::Migratable#migrate)
    def migrate(row, migrated)
      super
      tmpl = TEMPLATES.detect { |site| name[site.name.gsub(' ', '_')] }
      # merge the default mandatory attribute values
      if tmpl then merge(tmpl, mandatory_attributes) end
    end
    
    private
    
    TEMPLATES = [Galena::Seed.defaults.hospital, Galena::Seed.defaults.tissue_bank]
  end

  class StorageContainer
    # Augments {CaRuby::Migratable#migrate} for the example by setting the
    # the container site and type to the {Galena::Seed::Defaults}
    # box site and type, resp.
    #
    # @param (see CaRuby::Migratable#migrate)
    def migrate(row, migrated)
      super
      self.site ||= Galena::Seed.defaults.tissue_bank
      self.storage_type ||= Galena::Seed.defaults.box_type
    end
  end
  
  class User
    # Augments {CaRuby::Migratable#migrate} for the example as follows:
    # * infer the first and last name from the email address
    # * copy the address and organizations from the tissue bank coordinator 
    #
    # @param (see CaRuby::Migratable#migrate)
    def migrate(row, migrated)
      super
      # invent the mandatory name fields based on the email address, if necessary
      if email_address then
        n1, n2 = email_address[/[^@]+/].split('.')
        if n2 then
          first, last = n1, n2
        else
          first = 'Oscar'
          last = n1.capitalize
        end
        self.first_name = n1.capitalize
        self.last_name = n2.capitalize
      end
      # the coordinator serves as the User content template
      coord = Galena::Seed.defaults.hospital.coordinator
      # deep copy of the address
      self.address = coord.address.copy
      # shallow copy of the mandatory references
      merge(coord, [:cancer_research_group, :department, :institution])
    end
  end
end
