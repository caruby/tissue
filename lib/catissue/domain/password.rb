module CaTissue
  # import the Java class
  java_import Java::edu.wustl.catissuecore.domain.Password

  class Password
    include Resource

    qualify_attribute(:update_date, :unsaved)

  end
end