require 'catissue/annotation/annotation_class'

module CaTissue
  module Annotation
    module Importer
      private
    
      # Augments +Jinx::Importer.introspect+ to make the given class an
      # {AnnotationClass} prior to introspection.
      #
      # @param [Class] the domain class to introspect
      def introspect(klass)
        klass.extend(AnnotationClass)
        super
      end
      
      # Augments +Jinx::Importer.add_metadata+ to add annotation meta-data to
      # the introspected class.
      #
      # @param [AnnotationClass] klass the domain class
      def add_metadata(klass)
        super
        # Build the annotation metadata.
        klass.add_annotation_metadata(self)
        # Register the annotation class.
        annotation_classes << klass
        
        # Annotation classes are introspected, but the annotation constant is not set properly
        # in the annotation module. This occurs sporadically, e.g. in the PSBIN migration_test
        # test_biopsy_target test case the NewDiagnosisHealthAnnotation class is introspected
        # but when subsequently referenced by the migrator, the NewDiagnosisHealthAnnotation
        # class is not introspected and the class object id differs from the original class
        # object id. However, the analogous test_surgery_target does not exhibit this defect.
        #
        # The cause of this bug is a complete mystery. The work-around is to get the constant.
        # below. This is a seemingly unnecessary action to take, but was the most reasonable
        # remedy. The const_get can only be done with annotation classes, and breaks
        # non-annotation classes.
        const_get(klass.name.demodulize)
      end
    end
  end
end