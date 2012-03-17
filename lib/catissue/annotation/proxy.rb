module CaTissue
  module Annotation
    # {CaTissue::Resource} annotation hook proxy mix-in.
    module Proxy
      # @return [Annotatable] the annotated domain object  
      def hook
        send(self.class.owner_property.reader)
      end
      
      # @param [Annotatable] obj the domain object to annotate  
      def hook=(obj)
        send(self.class.owner_property.writer, obj)
      end
      
      # Ensures that this proxy's hook exists in the database.
      def ensure_hook_exists
        if hook.nil? then raise AnnotationError.new("Annotation proxy #{self} is missing the hook domain object") end
        hook.ensure_exists
      end
    end
  end
end
