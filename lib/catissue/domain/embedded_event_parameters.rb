module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.EmbeddedEventParameters')

  class EmbeddedEventParameters
    include Resource

    add_attribute_aliases(:medium => :embedding_medium)
  end
end