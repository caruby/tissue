require 'singleton'
require 'catissue'

module Galena
  # Creates the {Galena::Seed::Defaults} administrative objects as necessary.
  def self.seed
    Seed.defaults.ensure_exists
  end
  
  # Galena example utility module to populate the database with pre-defined administrative objects.
  module Seed
    # @return [Defaults] the defaults instance
    def self.defaults
      Defaults.instance
    end
  
    # Pre-defined Galena example administrative objects. If the Galena example is already set up
    # in the caTissue database, then the default object secondary key attributes can be used as a
    # {CaRuby::Persistable#find} template to retrieve the existing objects. Otherwise, the Defaults
    # attributes can be created by calling {CaRuby::Persistable#create}.
    #
    # In a real-world use case, the administrative objects are typically built in the UI before-hand.
    # In that case, it is only necessary to define the object secondary key rather than content, e.g.:
    #   pcl = CaTissue::CollectionProtocol.new(:short_title => 'Galena CP')
    # The complete definitions are included in this method for convenience in order to seed the
    # example in a test database. A real-world migration might find it useful to create a similar
    # defaults file in order to rapidly seed an empty test or staging database.
    class Defaults
      include Singleton
  
      attr_reader :protocol, :hospital, :tissue_bank, :freezer_type, :box_type
  
      # Creates the Galena example Defaults singleton and populates the attributes.
      def initialize
        super
        populate
      end
      
      # Creates the Galena example administrative objects as necessary.
      def ensure_exists
        @protocol.find(:create)
        @hospital.find(:create)
        @surgeon.find(:create)
        @box_type.find(:create)
      end
  
      private
  
      # Sets the Galena example Defaults attributes to new objects.
      def populate
        galena = CaTissue::Institution.new(:name => 'Galena University')
  
        addr = CaTissue::Address.new(
          :city => 'Galena', :state => 'Illinois', :country => 'United States', :zipCode => '37544',
          :street => '411 Basin St', :phoneNumber => '311-555-5555')
  
        dept = CaTissue::Department.new(:name => 'Pathology')
  
        crg = CaTissue::CancerResearchGroup.new(:name => 'Don Thomas Cancer Center')
  
        coord = CaTissue::User.new(
          :email_address => 'corey.nator@galena.edu',
          :last_name => 'Nator', :first_name => 'Corey', :address => addr.copy,
          :institution => galena, :department => dept, :cancer_research_group => crg)
  
        @hospital = CaTissue::Site.new(
            :site_type => CaTissue::Site::SiteType::COLLECTION, :name => 'Galena Hospital', 
            :address => addr.copy, :coordinator => coord)
  
        @tissue_bank = CaTissue::Site.new(
            :site_type => CaTissue::Site::SiteType::REPOSITORY, :name => 'Galena Tissue Bank', 
            :address => addr.copy, :coordinator => coord)
  
        pi = CaTissue::User.new(
          :email_address => 'vesta.gator@galena.edu',
          :last_name => 'Gator', :first_name => 'Vesta', :address => addr.copy,
          :institution => galena, :department => dept, :cancer_research_group => crg)
  
        @surgeon = CaTissue::User.new(
          :email_address => 'serge.on@galena.edu',
          :first_name => 'Serge', :last_name => 'On', :address => addr.copy,
          :institution => galena, :department => dept, :cancer_research_group => crg)
  
        @protocol = CaTissue::CollectionProtocol.new(:short_title => 'Galena Migration', 
          :principal_investigator => pi, :sites => [@tissue_bank])
  
        # CPE has default 1.0 event point and label
        cpe = CaTissue::CollectionProtocolEvent.new(:collection_protocol => @protocol)
        
        # the sole specimen requirement. Setting the requirement collection_event attribute to a CPE automatically
        # sets the CPE requirement inverse attribute in caRuby.
        CaTissue::TissueSpecimenRequirement.new(:collection_event => cpe, :specimen_type => 'Fixed Tissue')
  
        # the storage container type hierarchy
        @freezer_type = CaTissue::StorageType.new(:name => 'GTB Freezer', :columns => 10, :rows => 1, :column_label => 'Rack')
        rack_type = CaTissue::StorageType.new(:name => 'GTB Rack', :columns => 10, :rows => 10)
        @box_type = CaTissue::StorageType.new(:name => 'GTB Box', :columns => 10, :rows => 10)
        @freezer_type << rack_type
        rack_type << box_type
        @box_type << 'Tissue'
      end
    end
  end
end