require 'caruby/database/persistence_service'

module CaTissue
  module Annotation
    # An IntegrationService fetches and saves CaTissue 1.1.x hook-annotation associations.
    class IntegrationService < CaRuby::PersistenceService
      # Import the caTissue classes.
      java_import Java::deintegration.EntityMap
      java_import Java::deintegration.EntityMapRecord
      java_import Java::deintegration.FormContext

      def initialize
        super(SVC_NAME, CaTissue::Database.instance.access_properties)
      end

      # Associates the given hook domain object to the annotation.
      #
      # @param [Annotatable] hook the hook entity 
      # @param [Annotation] annotation the annotation entity 
      def associate(hook, annotation)
        # the annotation must have an identifier
        if annotation.identifier.nil? then
          raise CaRuby::DatabaseError.new("Annotation to associate does not have an identifier: #{annotation}")
        end
        emr = create_entity_map_record(hook, annotation)
        create(emr)
      end

      private
      
      SVC_NAME = 'deintegration'

      #### The cruft below is adapted from caTissue 1.1.2 ClientDemo_SCG.java and cleaned up (but still obscure). ####

      # Creates an entity map record with content (annotation entity id, annotation id, form context id).
      # This record associates the static hook record to the annotation record qualified by the context.
      #
      # @param (see #associate)
      # @return [EntityMapRecord] the new entity map record
      def create_entity_map_record(hook, annotation)
        # the entity map record with content (annotation entity id, annotation id, context id)
        emr = EntityMapRecord.new
        emr.static_entity_record_id = hook.identifier
        emr.dynamic_entity_record_id = annotation.identifier
        
        # the form context
        ctxt = form_context(hook, annotation)
        if ctxt then
          emr.form_context = ctxt
          emr.form_context_id = ctxt.id
        end
        
        emr
      end

      # @param (see #associate) 
      # @return [FormContent] an undocumented bit of caTissue presentation flotsam polluting the data layer
      def form_context(hook, annotation)
        map = entity_map(hook, annotation)
        
        # the fetched form context
        ctxts = map.form_context_collection
        if ctxts.empty? then
          logger.debug { "#{hook} entity map #{map.qp} does not have a form context." }
        elsif ctxts.size > 1 then
          ctxt_ids = ctxts.map { |ctxt| ctxt.id }
          raise CaRuby::DatabaseError.new("More than one form context for #{hook} - form context ids: #{ctxt_ids.qp}")
        else
          ctxt = ctxts.first
          logger.debug { "#{hook} has form context id #{ctxt.id}." }
        end
        
        ctxt
      end
      
      # @quirk caTissue the entity map is associated with a domain class in the hook class hierarchy.
      #   The generic approach to determining the entity map for a given hook object and annotation object
      #   is to iterate over the hook class hierarchy until a matching ENTITY_MAP record is found for the
      #   hook class ancestor and the annotation container id.
      #
      # @param (see #associate) 
      # @return [EntityMap] the entity map
      def entity_map(hook, annotation)
        klass = hook.class
        while klass < Java::EduWustlCommonDomain::AbstractDomainObject
          map = entity_map_for_class(klass, annotation)
          return map if map
          klass = klass.superclass
        end
        nil
      end
      
      # @param [Class] klass the hook class
      # @param annotation (see #entity_map) 
      # @return (see #entity_map)
      def entity_map_for_class(klass, annotation)
        # A query template
        tmpl = EntityMap.new
        tmpl.static_entity_id = klass.effective_entity_id
        # the container id
        tmpl.container_id = annotation.class.container_id
        # the database record matching the template
        logger.debug { "Fetching the ENTITY_MAP record for #{klass.qp} entity id #{tmpl.static_entity_id} and container id #{tmpl.container_id}..." }
        map = query(tmpl).first
        if map then
          logger.debug { "Entity map found for #{klass.qp} entity id #{tmpl.static_entity_id}, container id #{tmpl.container_id}: #{map.qp}." }
        else
          logger.debug { "ENTITY_MAP record not found for #{klass.qp} entity id #{tmpl.static_entity_id}, container id #{tmpl.container_id}." }
        end
        map
      end
    end
  end
end