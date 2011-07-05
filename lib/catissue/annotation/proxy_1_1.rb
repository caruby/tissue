require 'catissue/annotation/proxy'

module CaTissue
  module Annotation
    # caTissue 1.1.x {CaTissue::Resource} annotation hook proxy mix-in.
    module Proxy_1_1
      include Proxy
      
      # The hook proxy identifier is the hook identifier.
      # This method delegates to the hook.
      #
      # @return [Integer] the hook identifier
      def identifier
        hook.identifier if hook
      end
      
      # The proxy identifier cannot be set directly. Assignment is a no-op.
      #
      # @param [Integer] value the (ignored) identifier value
      def identifier=(value); end
      
      # @param [Annotatable] obj the domain object to annotate  
      def hook=(obj)
        super
        ensure_identifier_reflects_hook
      end
      
      # Ensures that this proxy's hook exists in the database. This proxy's identifier is set to
      # the hook identifier.
      def ensure_hook_exists
        super
        ensure_identifier_reflects_hook
      end
      
      private
      
      # Sets the +id+ Java property to the hook identifier.
      # This method must be called before saving a caTissue 1.1.x annotation that references this proxy.
      def ensure_identifier_reflects_hook
        if getId.nil? and hook and hook.identifier then
          setId(hook.identifier)
          logger.debug { "Set annotation proxy #{self} identifier to that of the hook entity #{hook.qp}." }
        end
      end
    end
  end
end
