require 'date'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.SpecimenProtocol
  
  # The SpecimenProtocol domain class.
  #
  # @quirk caTissue Bug #155: enrollment is incorrectly defined in SpecimenProtocol rather
  #   than CollectionProtocol. It is defaulted here until this defect is fixed.
  #
  # @quirk caTissue Augment the standard metadata storable reference attributes to work around caTissue Bug #150:
  #   Create CollectionProtocol in API ignores startDate.
  class SpecimenProtocol
    set_secondary_key_attributes(:title)

    add_attribute_defaults(:activity_status => 'Active', :enrollment => 0)

    add_mandatory_attributes(:principal_investigator, :activity_status, :start_date, :short_title)

    qualify_attribute(:start_date, :update_only)

    private

    # Sets the defaults if necessary. The start date is set to now. The title is
    # set to the short title.
    def add_defaults_local
      super
      self.title ||= short_title
      self.short_title ||= title
      self.start_date ||= Java::JavaUtil::Date.new
    end
  end
end