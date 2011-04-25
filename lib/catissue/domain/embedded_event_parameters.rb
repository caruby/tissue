module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.EmbeddedEventParameters

  class EmbeddedEventParameters < CaTissue::SpecimenEventParameters
    add_attribute_aliases(:medium => :embedding_medium)
  end
end