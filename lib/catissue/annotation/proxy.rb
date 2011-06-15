module CaTissue
  module Annotation
    # {CaTissue::Resource} annotation hook proxy mix-in.
    module Proxy
      # The hook proxy identifier is the hook identifier.
      # This method delegates to the hook.
      #
      # @return [Integer] the hook identifier
      def identifier
        hook.identifier if hook
      end
      
      # @return [Annotatable] the annotated domain object  
      def hook
        send(self.class.owner_attribute_metadata.reader)
      end
      
      # @param [Annotatable] obj the domain object to annotate  
      def hook=(obj)
        send(self.class.owner_attribute_metadata.writer, obj)
      end
      
      # The hook proxy identifier cannot be set directly. Assignment is a no-op.
      #
      # @param [Integer] value the (ignored) identifier value
      def identifier=(value); end
      
      # Sets the +id+ Java property to the hook identifier.
      # This method must be called before saving an annotation that references this proxy.
      def ensure_identifier_reflects_hook
        if getId.nil? then
          setId(hook.identifier)
          logger.debug { "Set annotation proxy #{self} identifier to that of the hook entity #{hook.qp}." }
        end
      end
    end
  end
end
