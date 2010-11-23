require 'caruby/util/properties'
require 'catissue/database/annotation/integration_service'
require 'catissue/database/annotation/annotatable_service'
require 'catissue/database/annotation/annotation_service'
require 'catissue/database/annotation/entity_manager'

module CaTissue
  module Annotation
    # An Annotator creates annotation services for annotatable and annotation classes.
    class Annotator
      def initialize(database)
        @database = database
        #the sole DE integration service, used by the annotation services
        @entity_manager = Annotation::EntityManager.instance
        @integration_service = Annotation::IntegrationService.new(@entity_manager)
        @anchor_svc_hash = {}
        @ann_mod_svc_hash = {}
      end

      # Returns the CaRuby::PersistenceService for the given klass, or nil if klass is neither
      # annotatable nor an annotation.
      def service(klass)
        annotatable_service(klass) or annotation_service(klass)
      end

      private

      # Returns the Annotation::AnnotatableService for the given klass, or nil if klass is not annotatable.
      def annotatable_service(klass)
        return @anchor_svc_hash[klass] ||= create_annotatable_service(klass) if JavaImport::AnnotatableClass === klass
        annotatable_service(klass.superclass) if klass.superclass
      end

      # Returns the Annotation::AnnotatorService for the given klass, or nil if klass is not an annotation.
      def annotation_service(klass)
        return @ann_mod_svc_hash[klass.annotation_module] ||= create_annotation_service(klass.annotation_module) if JavaImport::AnnotationClass === klass
        annotation_service(klass.superclass) if klass.superclass
      end

      def create_annotatable_service(klass)
        Annotation::AnnotatableService.new(@database, @database.persistence_service, @integration_service)
      end

      def create_annotation_service(mod)
        Annotation::AnnotationService.new(@database, mod.service, :anchor => mod.anchor_class, 
          :integration_service => @integration_service, :entity_manager => @entity_manager)
      end

      # TODO - delete if obsolete
      # Returns the class => annotator hash from the given database's properties.
      def create_service_hashes(database)
        @anchor_svc_hash = {}
        @pkg_svc_hash = {}
        #the sole DE integration service, used by the annotation services
        integration_service = Annotation::IntegrationService.new
        entity_manager = Annotation::EntityManager.instance
        # the anchor class => { package => { attribute => type } } hash
        anchor_pkg_attrs_hash = CaTissue.access_properties[CaRuby::Domain::Properties::ANNOTATIONS_PROP]
        return {} if anchor_pkg_attrs_hash.nil?
        # the package => service name hash
        pkg_svc_nm_hash = CaTissue.access_properties[CaRuby::Domain::Properties::ANN_SVCS_PROP]
        if pkg_svc_nm_hash.nil? then
          raise CaRuby::ConfigurationError.new("Annotation service property missing: #{CaRuby::Domain::Properties::ANN_SVCS_PROP}")
        end
        # build the anchor => service and package => service hashes
        anchor_service = Annotation::AnnotatableService.new(database, database.persistence_service, integration_service)
        # make an annotatable service for each anchor and an annotator service for each package
        anchor_pkg_attrs_hash.each do |anchor_cls_nm, pkg_signatures_hash|
          anchor_class = CaTissue.const_get(anchor_cls_nm)
          @anchor_svc_hash[anchor_class] = anchor_service
          pkg_signatures_hash.each do |pkg, signatures|
            svc_nm = pkg_svc_nm_hash[pkg]
            if svc_nm.nil? then
              raise CaRuby::DatabaseError.new("Annotation service property value missing for package #{pkg} in property #{CaRuby::Domain::Properties::ANN_SVCS_PROP}")
            end
            @pkg_svc_hash[pkg] = Annotation::AnnotationService.new(database, svc_nm, :anchor => anchor_class, 
              :integration_service => integration_service, :entity_manager => entity_manager)
            logger.debug { "Annotator service #{anchor_class.qp} #{svc_nm} created for attributes #{signatures.pp_s(:single_line)}" }
          end
        end
      end
    end
  end
end