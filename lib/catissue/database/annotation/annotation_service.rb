require 'jinx/helpers/inflector'
require 'caruby/database/sql_executor'
require 'caruby/database/persistence_service'
require 'caruby/database/url_application_service'

module CaTissue
  module Annotation
    # An AnnotationService queries and saves CaTissue annotations.
    class AnnotationService < CaRuby::PersistenceService
      # Creates an AnnotationService for the given CaTissue::Database, service name and options.
      #
      # @param [CaTissue::Database] database the database
      # @param [String] name the caTissue DE service name
      # @param [Integrator] integrator the caTissue annotation integrator
      def initialize(database, name, integrator)
        url = database.application_service_url_for(name)
        super() { CaRuby::URLApplicationService.for(url) }
        @database = database
        @intgtr = integrator
      end

      # Augments the +CaRuby::PersistenceService+ create method to handle caTissue annotation
      # service peculiarities, e.g.:
      # * assigns the identifier, since assignment is not done automatically as is the case with
      #   the default application service
      # * associate the annotation to the hook object
      # * Save all referenced annotation objects
      #
      # This method is only called on {Metadata#primary?} annotation objects.
      # 
      # @param [Annotation] annotation the annotation object to create
      # @return [Annotation] the annotation
      def create(annotation)
        logger.debug { "Creating annotation #{annotation.qp}..." }
        time { create_annotation(annotation) }
        logger.debug { "Created annotation #{annotation}." }
        annotation
      end
      
      private

      # @param [Annotation] (see #create)
      def create_annotation(annotation)
        if annotation.class.primary? then
          create_primary_annotation(annotation, annotation.hook)
        else
          create_nonprimary_annotation(annotation)
        end
        # Create the "cascaded" references.
        annotation.class.save_dependent_attributes(annotation)
      end
      
      # @param annotation (see #create)
      # @param [Annotable] the annotatable object referenced by this annotation
      def create_primary_annotation(annotation, hook)
        if @intgtr.order == :prefix then
          @intgtr.associate(hook, annotation)
        end
        # write the annotation records
        create_annotation_object(annotation)
        # If the annotation references a hook, then delegate to the integration service to associate
        # the hook to the annotation.
        if @intgtr.order == :postfix then
          @intgtr.associate(hook, annotation)
        end
      end
      
      def create_nonprimary_annotation(annotation)
        # the owner annotation
        ownr = annotation.owner
        if ownr.nil? then
          raise AnnotationError.new("Cannot create secondary annotation #{annotation.qp} since it does not have an owner")
        end
        # creating the owner creates this secondary
        logger.debug { "Created secondary annotation #{annotation} by creating the owner annotation #{ownr}..." }
        create(ownr)
      end
      
      # @see #create
      def create_annotation_object(annotation)
        # The next database identifier.
        annotation.identifier = EntityFacade.instance.next_identifier(annotation)
        # Ensure that there is a hook.
        ensure_hook_exists(annotation)
        # Delegate to standard record create.
        app_service.create_object(annotation)
        logger.debug { "Created annotation object #{annotation}." }
      end
      
      
      # Ensures that this proxy's hook exists in the database.
      def ensure_hook_exists(annotation)
        hook = annotation.hook
        if hook.nil? then raise AnnotationError.new("Annotation proxy #{annotation} is missing the hook domain object") end
        hook.ensure_exists
      end
    end
  end
end
