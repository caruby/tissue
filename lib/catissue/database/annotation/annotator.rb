require 'catissue/database/annotation/integrator'
require 'catissue/database/annotation/annotation_service'
require 'catissue/database/annotation/entity_facade'

module CaTissue
  # An Annotator creates annotation services for annotatable and annotation classes.
  class Annotator
    attr_reader :integrator
    
    # Initializes a new Annotator for the given database.
    #
    # @param [CaTissue::Database] the database
    def initialize(database)
      @database = database
    end

    # @param [Module] the annotation module
    # @param [String] name the service name
    # @return [Annotation::AnnotationService] the annotation service
    def create_annotation_service(mod, name)
      @integrator = Annotation::Integrator.new(mod)
      Annotation::AnnotationService.new(@database, name, @integrator)
    end
  end
end