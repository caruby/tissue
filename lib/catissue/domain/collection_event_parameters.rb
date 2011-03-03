require 'catissue/domain/scg_event_parameters'

module CaTissue
  # import the Java class
  java_import Java::edu.wustl.catissuecore.domain.CollectionEventParameters

  class CollectionEventParameters
    include Resource, SCGEventParameters

    add_attribute_defaults(:collection_procedure => 'Not Specified', :container => 'Not Specified')

  end
end