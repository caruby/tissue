require 'caruby/util/validation'
require 'catissue/resource'
require 'catissue/util/person'

module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.User')

  # The User domain class.
  class User
    include Person, Resource

    # caTissue alert - work-around for caTissue Bug #66 - Client missing CSException class et al.
    # caTissue User class initializes roleId to "", which triggers a client exception on subsequent
    # getRoleId call. Use a private variable instead and bypass getRoleId.
    def role_id
      # TODO - uncomment following and get rid of @role_id i.v. when bug is fixed.
      #value = send(old_method)
      #return if value == ''
      #value.to_i
      @role_id
    end

    # Sets the role id to the given value, which can be either a String or an Integer.
    # An empty or zero value is converted to nil.
    #
    # caTissue alert - caTissue API roleId is a String although the intended value domain is the
    # integer csm_role.identifier.
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

    # make the convenience Person name a first-class attribute
    add_attribute(:name)

    # caTissue alert - clinical study is unsupported by caTissue.
    remove_attribute(:clinical_studies)

    # clarify that collection_protocols is a coordinator -> protocol association.
    # make assigned protocol and site attribute names consistent.
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

    # caTissue alert - obscure GUI artifact User page_of attribute is insinuated into the data
    # layer as a required attribute. Work-around is to simulate the GUI with a default value.
    add_mandatory_attributes(:activity_status, :address, :cancer_research_group, :department,
      :email_address, :first_name, :institution, :last_name, :page_of, :role_id)

    add_dependent_attribute(:address)

    add_dependent_attribute(:passwords)

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

    # By default, the emailAddress is the same as the loginName.
    def add_defaults_local
      super
      self.login_name ||= email_address
      self.email_address ||= login_name
    end
  end
end