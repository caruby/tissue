require 'catissue/database/annotation/integrator_1_2'
require 'catissue/database/annotation/annotation_service'
require 'catissue/database/annotation/entity_facade'

module CaTissue
  # An Annotator_1_@ creates pre-2.0 caTissue annotation services for annotatable and annotation classes.
  class Annotator_1_2
    attr_reader :integrator
    
    # Initializes a new annotator for the given database.
    #
    # @param [Database] the database
    def initialize(database)
      @database = database
    end

    # @param [Module] the annotation module
    # @param [String] name the service name
    # @return [Annotation::AnnotationService] the annotation service
    def create_annotation_service(mod, name)
      @integrator = Annotation::Integrator_1_2.new(@database, mod)
      Annotation::AnnotationService.new(@database, name, @integrator)
    end
  end
end