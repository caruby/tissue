require 'jinx/helpers/inflector'
require 'jinx/migration/migratable'
require 'galena/seed'

module CaTissue
  # Augment the classes below with sufficient content to pass the create mandatory attribute validation.
  # This simulates an existing administrative object for testing purposes.
  #
  # This file is not placed in the specs support directory, since it is dynamically loaded as a shim.
  shims CollectionProtocol, CollectionProtocolEvent, Site, StorageContainer, User

  class CollectionProtocol
    # Augments +Jinx::Migratable.migrate+ for the Galena example by adding the following defaults:
    # * the CP principal_investigator defaults to the {Galena::Seed#protocol} PI
    # * if the sites is empty, then the {Galena::Seed#tissue_bank} is added
    #   to the CP sites
    #
    # @param (see Jinx::Migratable#migrate)
    def migrate(row, migrated)
      super
      self.title ||= migration_default_title(migrated)
      self.principal_investigator ||= Galena.administrative_objects.protocol.principal_investigator
      sites << Galena.administrative_objects.tissue_bank if sites.empty?
      coordinators << Galena.administrative_objects.tissue_bank.coordinator if coordinators.empty?
    end
    
    private
    
    # @param (see #migrate)
    # @return [String, nil] the short title of the {Galena::Seed} protocol which
    #   matches this protocol's event, or nil if no match 
    def migration_default_title(migrated)
      cpe = migrated.detect { |obj| CaTissue::CollectionProtocolEvent === obj } || return
      pcl = Galena.administrative_objects.protocols.detect { |p| p.events.first.label == cpe.label } || return
      pcl.title
    end
  end
  
  class CollectionProtocolEvent
    # Augments +Jinx::Migratable.migrate+ for the example by adding the following defaults:
    # * create a {CaTissue::TissueSpecimenRequirement}
    # * copy the event point from {Galena::Seed}
    #
    # @param (see Jinx::Migratable#migrate)
    def migrate(row, migrated)
      super
      match = Galena.administrative_objects.protocols.detect_value do |pcl|
        cpe = pcl.events.first
        cpe if cpe.label == label
      end
      if match then
        self.event_point ||= match.event_point
        rqmt = match.requirements.first
        CaTissue::TissueSpecimenRequirement.new(:collection_event => self, :specimen_type => rqmt.specimen_type)
      else
        CaTissue::TissueSpecimenRequirement.new(:collection_event => self)
      end
    end
  end

  class Site
    # Augments +Jinx::Migratable.migrate+ for the example by merging the content of the
    # {Galena::Seed} site which matches on this Site's name, if any.
    #
    # @param (see Jinx::Migratable#migrate)
    def migrate(row, migrated)
      super
      # Match the site by name. Account for uniquification by a partial match, e.g.
      # 'Galena_Hospital_41893443' matches the site named 'Galena Hospital'.
      tmpl = TEMPLATES.detect { |site| name[site.name.gsub('_', ' ')] }
      # merge the default mandatory attribute values
      if tmpl then merge(tmpl, mandatory_attributes) end
    end
    
    private
    
    TEMPLATES = [Galena.administrative_objects.hospital, Galena.administrative_objects.tissue_bank]
  end

  class StorageContainer
    # Augments +Jinx::Migratable.migrate+ for the example by setting the
    # the container site and type to the {Galena::Seed}
    # box site and type, resp.
    #
    # @param (see Jinx::Migratable#migrate)
    def migrate(row, migrated)
      super
      self.site ||= Galena.administrative_objects.tissue_bank
      self.storage_type ||= Galena.administrative_objects.box_type
    end
  end
  
  class SpecimenEventParameters
    # Fills in the event parameters user details.
    #
    # @param (see Jinx::Migratable#migrate)
    def migrate(row, migrated)
      user.migrate(row, migrated) if user
    end
  end
  
  class User
    # Augments +Jinx::Migratable.migrate+ for the example as follows:
    # * infer the first and last name from the email address
    # * copy the address and organizations from the tissue bank coordinator 
    #
    # @param (see Jinx::Migratable#migrate)
    def migrate(row, migrated)
      super
      # Invent the mandatory name fields based on the login, if necessary.
      if login_name then
        last, first = login_name[/[^@]+/].split('.').reverse.map { |s| s.capitalize }
        first ||= 'Oscar'
        self.first_name ||= first
        self.last_name ||= last
      end
      # the coordinator serves as the User content template
      coord = Galena.administrative_objects.hospital.coordinator
      # deep copy of the address
      self.address ||= coord.address.copy
      # shallow copy of the mandatory references
      merge(coord, [:cancer_research_group, :department, :institution])
    end
  end
end
