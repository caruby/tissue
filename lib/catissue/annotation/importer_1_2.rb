require 'catissue/annotation/importer'

module CaTissue
  module Annotation
    # This Annotation Importer module extends the standard +Jinx::Importer+ to import caTissue 1.2
    # annotation classes.
    module Importer_1_2
      include Importer
      
      attr_reader :record_entry_class
      
      def enable_metadata(hook, opts)
        super
        @svc_nm = opts[:service]
        begin
          @record_entry_class = integration_module.const_get(hook.name.demodulize + 'RecordEntry')
        rescue NameError
          # There is no RE class in pre-1.2 caTissue versions.
        end
      end
      
      # Returns the {AnnotationService} that mediates database access for this
      # annotation module.
      #
      # @quirk caTissue 2.0 Distinct annotation application services were discontinued
      #    in caTissue 2.0. Annotations use the generic caTissue application service
      #    instead.
      #
      # @return [CaRuby::PersistenceService] this module's application service
      def persistence_service
        @ann_svc ||= obtain_persistence_service
      end
      
      private
      
      def integration_module
        Integration_1_2
      end
      
      def obtain_persistence_service
        if @svc_nm then
          Database.current.annotator.create_annotation_service(self, @svc_nm)
        else
          Database.current.persistence_service(hook)
        end
      end        

      # @param [Metadata] klass the domain class
      def add_metadata(klass)
        super
        # TODO - confirm that the test_biopsy_target now works and remove this code.
        # # Annotation classes are introspected, but the annotation constant is not set properly
        # # in the annotation module. This occurs sporadically, e.g. in the PSBIN migration_test
        # # test_biopsy_target test case the NewDiagnosisHealthAnnotation class is introspected
        # # but when subsequently referenced by the migrator, the NewDiagnosisHealthAnnotation
        # # class object id differs from the original class object id. However, the analogous
        # # test_surgery_target does not exhibit this defect.
        # #
        # # The cause of this bug is a complete mystery. The work-around is to get the constant.
        # # below. This is a seemingly unnecessary action to take, but was the most reasonable
        # # remedy. The const_get can only be done with annotation classes, and breaks
        # # non-annotation classes.
        # const_get(klass.name.demodulize)
      end
    end
  end
end
