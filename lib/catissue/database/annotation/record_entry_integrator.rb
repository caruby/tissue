module CaTissue
  module Annotation
    java_import Java::edu.wustl.catissuecore.domain.StudyFormContext
    
    # A RecordEntryIntegrator uses the post-1.1.2 mechanism to save caTissue hook-annotation associations.
    class RecordEntryIntegrator
      # @param [AnnotationModule] mod the annotation module
      def initialize(mod)
        @mod = mod
        @ann_ctxt_hash = {}
      end

      # Associates the given hook domain object to the annotation.
      #
      # @param [Annotatable] hook the hook entity 
      # @param [Annotation] annotation the annotation entity 
      def associate(hook, annotation)
        rec_entry = create_record_entry(hook, annotation)
        annotation.proxy.identifier = rec_entry.getId
      end

      private
      
      # @param (see #associate)
      # @return [Object] yet another association record which associates the hook to the
      #   annotation in the {REC_ENTRY_PKG}
      def create_record_entry(hook, annotation)
        # the record entry object
        re = @mod.record_entry_class.new
        # the activity status must be set for the DE to show up
        re.activity_status = 'Active'
        # the form context
        re.form_context = form_context(hook, annotation)
        re.send(@mod.record_entry_hook_writer, hook)
        # dispatch to the application service
        toxic = hook.persistence_service.create(re)
        # copy the created identifier
        re.setId(toxic.getId)
        re
      end
      
      # @param (see #associate)
      # @return [FormContext] an undocumented bit of caTissue presentation flotsam polluting the data layer
      def form_context(hook, annotation)
        @ann_ctxt_hash[annotation.class] ||= fetch_form_context(hook, annotation)
      end
      
      # @param (see #associate)
      # @return (see #form_context)
      def fetch_form_context(hook, annotation)
        tmpl = StudyFormContext.new
        tmpl.container_id = annotation.class.container_id
        ctxts = hook.persistence_service.query(tmpl)
        case ctxts.size
          when 0 then raise AnnotationError.new("Form context not found for annotation class #{annotation.class.qp}")
          when 1 then ctxts.first
          else raise AnnotationError.new("Multiple form contexts found for annotation class #{annotation.class.qp}")
        end
      end
    end
  end
end