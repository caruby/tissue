module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.Password

  class Password
    qualify_attribute(:update_date, :unsaved)

  end
end