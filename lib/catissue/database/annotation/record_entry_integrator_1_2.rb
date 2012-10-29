module CaTissue
  module Annotation
    java_import Java::edu.wustl.catissuecore.domain.StudyFormContext
    
    # A RecordEntryIntegrator uses the caTissue 1.2 mechanism to save hook-annotation associations.
    class RecordEntryIntegrator_1_2
      # @param [AnnotationModule] mod the annotation module
      def initialize(mod)
        @mod = mod
        @ann_ctxt_hash = {}
      end

      # Associates the given hook domain object to the annotation.
      #
      # @quirk caTissue The static hook entity is associated with the annotation
      #   by creating a record entry hook proxy. Even though the record entry class
      #   includes Java properties for each primary annotation in the annotation
      #   Java package, the record entry instance only references a single annotation.
      #   The record entry database table +dyextn_abstract_record_entry+ has a foreign
      #   key reference to the +ABSTRACT_FORM_CONTEXT_ID+. A separate record entry is
      #   created for each annotation.
      #
      # @param [Annotatable] hook the hook entity 
      # @param [Annotation] annotation the annotation entity 
      def associate(hook, annotation)
        rec_entry = create_record_entry(hook, annotation)
        annotation.proxy.identifier = rec_entry.getId
      end

      private
      
      # @param (see #associate)
      # @return [Object] yet another association record which associates the hook to the annotation
      def create_record_entry(hook, annotation)
        # the DE integration record entry class
        re = annotation.proxy
        # set the form context
        re.form_context = form_context(hook, annotation)
        # set the hook
        re.set_property_value(re.class.hook_property, hook)
        logger.debug { "The #{hook} is associated with the annotation #{annotation} through the record entry #{re.class} #{re}." }
        # dispatch to the application service
        toxic = hook.persistence_service.create(re)
        # copy the created identifier
        re.identifier = toxic.getId
        # set the proxy proxy identifier
        re.proxy_proxy.identifier = re.identifier
        logger.debug { "The #{hook} annotation #{annotation} record entry #{re.class} #{re} proxy proxy is #{re.proxy_proxy.class} #{re.proxy_proxy}." }
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
        ctr_id = annotation.class.container_id
        if ctr_id.nil? then
          raise AnnotationError.new("#{hook.class.qp} annotation #{annotation.class} doesn't have the required container id")
        end
        tmpl.container_id = ctr_id
        ctxts = hook.persistence_service.query(tmpl)
        ctxt = case ctxts.size
          when 0 then raise AnnotationError.new("Form context not found for annotation class #{annotation.class.qp}")
          when 1 then ctxts.first
          else raise AnnotationError.new("Multiple form contexts found for annotation class #{annotation.class.qp}")
        end
        logger.debug { "#{annotation.qp} form context is #{ctxt}." }
        ctxt
      end
    end
  end
end