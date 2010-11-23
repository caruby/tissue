require 'caruby/database/persistence_service'

module CaTissue
  module Annotation
    # An IntegrationService fetches and saves CaTissue anchor-annotation associations.
    class IntegrationService < CaRuby::PersistenceService
      SERVICE_NAME = 'deintegration'

      java_import('deintegration.EntityMap')
      java_import('deintegration.EntityMapRecord')

      def initialize(entity_manager)
        super(SERVICE_NAME)
        @entity_manager = entity_manager
      end

      # Associates the given anchor domain object to annotation.
      def associate(anchor, annotation)
        logger.debug { "Associating annotation #{annotation} to owner #{anchor}..." }
        association = create_entity_map_record(anchor, annotation)
        create(association)
      end

      # Removes the existing association between the given anchor domain object to annotation.
      def dissociate(anchor, annotation)
        association = create_entity_map_record(anchor, annotation)
        delete(association)
      end

      private

      # Flag to work around caTissue and JRuby bugs
      ENTITY_MAP_BUG = true

      ## The cruft below is adapted from caTissue ClientDemo_SCG.java and cleaned up (but still obscure). ##

      def create_entity_map_record(anchor, annotation)
        record = EntityMapRecord.new
        raise CaRuby::DatabaseError.new("Annotation entity map static entity does not have an identifier: #{anchor}") if anchor.identifier.nil?
        record.static_entity_record_id = anchor.identifier
        raise CaRuby::DatabaseError.new("Annotation entity map dynamic entity does not have an identifier: #{annotation}") if annotation.identifier.nil?
        record.dynamic_entity_record_id = annotation.identifier
        record.form_context = form_context(anchor, annotation)
        record.form_context_id = record.form_context.identifier if record.form_context
        record
      end

      # Returns the undocumented caTissue FormContext, which might be another bit of caTissue presentation
      # flotsam polluting the data layer.
      def form_context(anchor, annotation)
        map = EntityMap.new
        map.static_entity_id = anchor_entity_id(anchor)
        return if ENTITY_MAP_BUG
        # 2 bugs:
        # * caTissue bug - bad container id query, cf. https://cabig-kc.nci.nih.gov/Biospecimen/forums/viewtopic.php?f=19&t=421&sid=5252d951301e598eebf3e90036da43cb
        # * jRuby bug? - query on map call to map.pp_s wipes out the map java_class! Can't step into pp_s with debugger so can't isolate cause without more work
        # TODO - isolate and file both bugs
        #map.container_id = entity_container_id(annotation)
        map.form_context_collection.first if query(map)
      end

      def entity_container_id(annotation)
        entity_id = annotation_entity_id(annotation)
        container_id = @entity_manager.get_container_id_for_entity(entity_id)
        raise CaRuby::DatabaseError.new("Dynamic extension container id not found for annotation #{annotation}") if container_id.nil?
        logger.debug { "Dynamic extension container id for #{annotation}: #{container_id}" } and container_id
      end

      # Returns the undocumented caTissue entity id for the given anchor entity's Java class name.
      def anchor_entity_id(anchor)
        entity_id_for_class_designator(anchor.class.java_class.name)
      end

      # Returns the undocumented caTissue entity id for the given annotation entity's demodulized Java class name.
      #
      # caTissue alert - unlike #anchor_entity_id, {#annotation_entity_id} strips the leading package prefix from the annotation
      # class name. caTissue DE API requires this undocumented inconsistency.
      def annotation_entity_id(annotation)
        entity_id_for_class_designator(annotation.class.java_class.name[/[^.]+$/])
      end

      def entity_id_for_class_designator(designator)
        @entity_manager.get_entity_id(designator) or raise CaRuby::DatabaseError.new("Dynamic extension entity id not found for #{designator}")
      end
    end
  end
end