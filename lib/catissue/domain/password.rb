module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.Password')

  class Password
    include Resource

    qualify_attribute(:update_date, :unsaved)

  end
end