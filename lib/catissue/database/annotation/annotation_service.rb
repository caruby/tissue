require 'caruby/util/inflector'
require 'caruby/database/sql_executor'
require 'caruby/database/persistence_service'
require 'catissue/annotation/annotatable'

module CaTissue
  module Annotation
    # An AnnotationService queries and saves CaTissue annotations.
    class AnnotationService < CaRuby::PersistenceService
      # Creates an AnnotationService for the given CaTissue::Database, service name and options.
      #
      # @param [CaTissue::Database] database the database
      # @param [String] name the caTissue DE service name
      # @param (see CaRuby::PersistenceService#initialize)
      # @option opts :hook the required hook class
      # @option opts :integration_service the required IntegrationService
      # @option opts (see CaRuby::PersistenceService#initialize)
      def initialize(database, name, opts)
        super(name, opts)
        @database = database
        @database.add_persistence_service(self)
        @int_svc = opts[:integration_service]
      end

      # Augments the {CaRuby::PersistenceService} create method to handle caTissue annotation
      # service peculiarities, e.g.:
      # * assigns the identifier, since assignment is not done automatically as is the case with the
      #   default application service
      # * associate the annotation to the hook object
      # * Save all referenced annotation objects
      #
      # This method can only be called on primary annotation objects. A _primary_ annotation
      # is a top-level annotation which has a reference to the {Annotation#hook} which is
      # being annotated.
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
         # get the hook
        hook = annotation.hook
        # If no hook, then this is not a primary annotation. In that case, find a referenced
        # primary annotation.
       # If no hook, then this is not a primary annotation. In that case, find a referenced
        # primary annotation.
        if hook then
          create_primary_annotation(annotation, hook)
        else
          create_secondary_annotation(annotation)
        end
      end
      
      # @param annotation (see #create)
      # @param [Annotable] the annotatable object referenced by this annotation
      def create_primary_annotation(annotation, hook)
        # write the annotation records
        create_annotation_object(annotation)
        # Create the "cascaded" references.
        annotation.class.save_dependent_attributes(annotation)
        # If the annotation references a hook, then delegate to the integration service to associate
        # the hook to the annotation.
        @int_svc.associate(hook, annotation)
      end
      
      def create_secondary_annotation(annotation)
        # the owner annotation
        ownr = annotation.owner
        if ownr.nil? then
          raise AnnotationError.new("Cannot create secondary annotation #{annotation.qp} since it does not have an owner")
        end
        # creating the owner creates this secondary
        create(ownr)
      end
      
      # @see #create
      def create_annotation_object(annotation)
        # can't create a proxy
        if Proxy === annotation then
          raise AnnotationError.new("#{annotation} annotation proxy create is not supported")
        end
        # The sequence generator next id.
        annotation.identifier = EntityFacade.instance.next_identifier(annotation)
        # Ensure that the proxy record is up-to-date.
        annotation.ensure_proxy_reflects_hook
        
        # Delegate to standard record create.
        app_service.create_object(annotation)
      end
    end
  end
end