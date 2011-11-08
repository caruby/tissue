require 'singleton'
require 'caruby/util/validation'
require 'caruby/util/uniquifier'

module CaTissue
  module TestCase
    # caTissue test default admin fixture.
    class Seed
      include Enumerable

      attr_reader :tissue_bank, :protocol, :registration, :specimen,
        :specimen_requirement, :specimen_collection_group, :box
  
      def initialize
        populate
      end
  
      # @return [<CaTissue::Resource>] this fixture's domain objects
      def domain_objects
        instance_variables.map { |iv| instance_eval iv }.select { |value| CaRuby::Resource === value }
      end

      # Adds default values to this fixture's domain objects.
      def add_defaults
        domain_objects.each { |obj| obj.add_defaults unless obj.equal?(specimen) }
        # Add specimen default values last, since SCG add_specimens propagates the collection event
        # necessary to set the default specimen label.
        specimen.add_defaults
        self
      end

      # Fetches the default instances from the database. Creates new objects if necessary.
      #
      # @raise [ValidationError] if a domain object fails validation
      def validate
        # identifiers are required for validation; these are removed following validation
        objs_without_ids = domain_objects.select { |obj| obj.identifier.nil? }
        objs_without_ids.each_with_index { |obj, index| obj.identifier = index + 1 }
        domain_objects.each { |obj| obj.validate }
        # restore null identifiers
        objs_without_ids.each { |obj| obj.identifier = nil }
        self
      end

      # Creates this fixture's {#domain_objects} in the database, if necessary.
      def ensure_exists
        domain_objects.each { |obj| obj.find(:create) unless obj.identifier or obj.class.dependent? }
      end

      # Repopulates the defaults and makes the following attributes unique:
      # * collection_protocol short title
      # * participant MRN
      # * specimen label
      #
      # @return this fixture
      def uniquify
        # make the CP and MRN unique; these values will ripple through the SCG, CPR, et al.
        # to make them unique as well
        @protocol.title = @protocol.title.uniquify
        @registration.participant.medical_identifiers.each { |mid| mid.medical_record_number = Uniquifier.qualifier }
        # unset the SCG name and specimen label so the default is set to a new unique value
        @specimen_collection_group.name = @specimen.label = nil
        self
      end
  
      private

      # Adds data to this fixture.
      #
      # @return this fixture
      def populate
        logger.debug { "Populating the test fixture..." }

        # the test institution
        inst = CaTissue::Institution.new(:name => 'Test Institution')

        # the standard test address
        addr = CaTissue::Address.new
        addr.city = 'Test City'
        addr.state = 'Other'
        addr.country = 'Niue'
        addr.zipCode = '55555'
        addr.street = '555 Test St'
        addr.phoneNumber = '555-555-5555'

        # the test department
        dept = CaTissue::Department.new(:name => 'Test Department')

        # the test cancer center
        cc = CaTissue::CancerResearchGroup.new(:name => 'Test Cancer Center')

        # the test tissue bank coordinator
        coord = CaTissue::User.new
        coord.loginName = coord.emailAddress = 'test_coordinator@example.edu'
        coord.lastName = 'Coordinator'
        coord.firstName = 'Test'
        coord.address = addr.copy
        coord.institution = inst
        coord.department = dept
        coord.cancer_research_group = cc
        coord.add_defaults

        # the test surgeon
        surgeon = CaTissue::User.new
        surgeon.loginName = surgeon.emailAddress = 'test_surgeon@example.edu'
        surgeon.lastName = 'Scientist'
        surgeon.firstName = 'Test'
        surgeon.address = addr.copy
        surgeon.institution = inst
        surgeon.department = dept
        surgeon.cancer_research_group = cc

        # the test PI
        pi = CaTissue::User.new
        pi.loginName = pi.emailAddress = 'test_scientist@example.edu'
        pi.lastName = 'Scientist'
        pi.firstName = 'Test'
        pi.address = addr.copy
        pi.institution = inst
        pi.department = dept
        pi.cancer_research_group = cc

        # the test hospital
        hospital = CaTissue::Site.new(
          :site_type => CaTissue::Site::SiteType::COLLECTION,
          :name => 'Test Collection Site',
          :address => addr.copy,
          :coordinator => coord
        )

        # the test tissue bank
        @tissue_bank = CaTissue::Site.new(
          :site_type => CaTissue::Site::SiteType::REPOSITORY,
          :name => 'Test Tissue Bank',
          :address => addr.copy,
          :coordinator => coord
        )
    
        # the test participant
        pnt = CaTissue::Participant.new(:name => 'Test Participant')

        # add the participant mrn
        mrn = 555555
        pnt.add_mrn(hospital, mrn)

        # the test collection protocol
        @protocol = CaTissue::CollectionProtocol.new(
          :title => 'Test CP',
          :principal_investigator => pi
        )

        # the test consent tier
        ctier = CaTissue::ConsentTier.new(:statement => 'Test Consent Statement')
        @protocol.consent_tiers << ctier

        # the collection event template
        cpe = CaTissue::CollectionProtocolEvent.new(:protocol => @protocol)

        # the participant collection registration
        @registration = @protocol.register(pnt)
        # add a consent tier response
        rsp = CaTissue::ConsentTierResponse.new(:consent_tier => ctier)
        @registration.consent_tier_responses << rsp

        # the specimen requirement template
        @specimen_requirement = CaTissue::TissueSpecimenRequirement.new(
          :collection_event => cpe,
          :specimen_type => 'Frozen Tissue',
          :specimen_characteristics => CaTissue::SpecimenCharacteristics.new,
          :pathological_status => 'Malignant')

        # the sole tissue specimen
        @specimen = CaTissue::Specimen.create_specimen(:requirement => @specimen_requirement, :initial_quantity => 4.0)

        # the SCG
        @specimen_collection_group = @protocol.add_specimens(
          @specimen,
          :participant => pnt,
          :collection_event => cpe,
          :collection_site => hospital,
          :receiver => coord)
          
        # a storage container
        frz_type = CaTissue::StorageType.new(:name => 'Test Freezer', :columns => 10, :rows => 1, :row_label => 'Rack')
        rack_type = CaTissue::StorageType.new(:name => 'Test Rack', :columns => 10, :rows => 10)
        box_type = CaTissue::StorageType.new(:name => 'Test Box', :columns => 10, :rows => 10)
        frz_type << rack_type
        rack_type << box_type
        box_type << 'Tissue'
        # a sample freezer box
        @box = CaTissue::StorageContainer.new(:storage_type => box_type, :site => @tissue_bank)

        logger.debug { "Test fixture populated." }
        self
      end
    end
  end
end