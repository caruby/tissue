require 'catissue/annotation/proxy'

module CaTissue
  module Annotation
    # caTissue 1.2 {CaTissue::Resource} annotation hook proxy mix-in.
    module RecordEntryProxy
      include Proxy

      # @return [Annotatable] the annotated domain object  
      def hook
        send(self.class.owner_property.reader)
      end
      
      # @param [Annotatable] obj the domain object to annotate  
      def hook=(obj)
        send(self.class.owner_property.writer, obj)
      end
    end
  end
end
