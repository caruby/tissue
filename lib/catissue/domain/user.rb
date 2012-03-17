require 'jinx/helpers/validation'
require 'catissue/helpers/person'

module CaTissue
  # The User domain class.
  #
  # @quirk caTissue caTissue 1.2 User has an adminuser Java property, but caTissue throws an
  #   UnsupportedOperationException if it's accessor method is called.
  #
  # @quirk caTissue clinical study is unsupported by 1.1.x caTissue, removed in 1.2.
  class User
    include Person

    # @quirk caTissue work-around for caTissue Bug #66 - Client missing CSException class et al.
    #   caTissue User class initializes roleId to "", which triggers a client exception on subsequent
    #   getRoleId call. Use a private variable instead and bypass getRoleId.
    #
    # @quirk caTissue 1.2 Call to getRoleId results in the following error:
    #     NoClassDefFoundError: gov/nih/nci/security/dao/SearchCriteria
    #   This bug is probably a result of caTissue "fixing" Bug #66.
    #   The work-around to the caTissue bug fix bug is to return nil unless the role id has been set
    #   by a call to the {#role_id=} setter method.
    def role_id
      @role_id
    end

    # Sets the role id to the given value, which can be either a String or an Integer.
    # An empty or zero value is converted to nil.
    #
    # @quirk caTissue caTissue API roleId is a String although the intended value domain is the
    #   integer csm_role.identifier.
    def role_id=(value)
      # value as an integer (nil is zero)
      value_i = value.to_i
      # set the Bug #66 work-around i.v.
      @role_id = value_i.zero? ? nil : value_i
      # value as a String (if non-nil)
      value_s = @role_id.to_s if @role_id
      # call Java with a String
      setRoleId(value_s)
    end

    if property_defined?(:adminuser) then remove_attribute(:adminuser) end

    # Make the convenience {CaRuby::Person::Name} name a first-class attribute.
    add_attribute(:name, CaRuby::Person::Name)

    if property_defined?(:clinical_studies) then remove_attribute(:clinical_studies) end

    # Clarify that collection_protocols is a coordinator -> protocol association.
    # Make assigned protocol and site attribute names consistent.
    add_attribute_aliases(:coordinated_protocols => :collection_protocols, :protocols => :assigned_protocols, :assigned_sites => :sites)

    # login_name is a database unique key.
    set_secondary_key_attributes(:login_name)

    # email_address is expected to be unique, and is enforced by the caTissue business logic.
    set_alternate_key_attributes(:email_address)

    # Set defaults as follows:
    # * page_of is the value set when creating a User in the GUI
    # * role id is 7 = Scientist (public)
    # * initial password is 'changeMe1'
    add_attribute_defaults(:activity_status => 'Active', :page_of => 'pageOfUserAdmin', :role_id => 7, :new_password => 'changeMe1')

    # @quirk caTissue obscure GUI artifact User page_of attribute pollutes the data layer as a
    #   required attribute. Work-around is to simulate the GUI with a default value.
    add_mandatory_attributes(:activity_status, :address, :cancer_research_group, :department,
      :email_address, :first_name, :institution, :last_name, :page_of, :role_id)

    # @quirk caTissue 1.2 User address can be updated in 1.1.2, but not 1.2. This difference is handled
    #   by the caRuby {CaTissue::Database} update case logic.
    #
    # @quirk caTissue 1.2 User address is fetched on create in 1.1.2, but not 1.2. This difference is
    #   handled by the caRuby {CaTissue::Database} create case logic.
    add_dependent_attribute(:address)

    # Password is removed as a visible caRuby attribute, since it is immutable in 1.2 and there
    # is no use case for its access.
    remove_attribute(:passwords)

    set_attribute_inverse(:protocols, :assigned_protocol_users)

    set_attribute_inverse(:sites, :assigned_site_users)
    
    qualify_attribute(:cancer_research_group, :fetched)

    qualify_attribute(:department, :fetched)

    qualify_attribute(:institution, :fetched)

    qualify_attribute(:protocols, :saved, :fetched)

    qualify_attribute(:sites, :saved)

    qualify_attribute(:page_of, :unfetched)

    qualify_attribute(:new_password, :unfetched)

    qualify_attribute(:role_id, :unfetched)

    private

    # By default, the email address is the same as the login name.
    def add_defaults_local
      super
      self.login_name ||= email_address
      self.email_address ||= login_name
    end
  end
end