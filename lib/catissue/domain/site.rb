module CaTissue
  # import the Java class
  java_import Java::edu.wustl.catissuecore.domain.Site

  # The Site domain class.
  class Site
    include Resource

    # caTissue alert - the Site SCG collection is ignored, since it is not fetched with the Site,
    # the caCORE query builder doesn't support abstract types, and even if it worked it would
    # have limited value but high fetch cost. The work-around, which is also the more natural
    # mechanism, is to query on a concrete SCG subclass template which references the target Site.
    remove_attribute(:abstract_specimen_collection_groups)

    set_secondary_key_attributes(:name)

    add_attribute_defaults(:activity_status => 'Active', :site_type => 'Not Specified')

    add_mandatory_attributes(:activity_status, :address, :coordinator, :site_type)

    add_dependent_attribute(:address)

    # The site_type value constants.
    class SiteType
      COLLECTION = 'Collection Site'
      LABORATORY = 'Laboratory'
      REPOSITORY = 'Repository'
    end
    
    def self.default_site
      @@def_site ||= new(:name => DEF_SITE_NAME)
    end
    
    private
        
    # The default pre-defined caTissue site name.
    DEF_SITE_NAME = 'In Transit'
  end
end