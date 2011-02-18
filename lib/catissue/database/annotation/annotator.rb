require 'catissue/database/annotation/integration_service'
require 'catissue/database/annotation/annotation_service'
require 'catissue/database/annotation/entity_facade'

module CaTissue
  # An Annotator creates annotation services for annotatable and annotation classes.
  class Annotator
    attr_reader :integration_service
    
    # Initializes a new Annotator for the given database.
    #
    # @param [CaTissue::Database] the database
    def initialize(database)
      @database = database
      #the sole DE integration service, used by the annotation services
      @integration_service = Annotation::IntegrationService.new
    end

    # @param [String] name the service name
    # @return [Annotation::AnnotationService] the annotation service
    def create_annotation_service(name)
      Annotation::AnnotationService.new(@database, name, :integration_service => @integration_service)
    end
  end
end