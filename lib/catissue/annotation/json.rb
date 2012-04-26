module CaTissue
  module Annotation
    module JSON
      private
      
      # The JSON class name must be scoped by the Resource package module, not the
      # Java package, in order to recognize the Jinx::Resource JSON hooks.
      #
      # @return [String] the class name qualified by the Resource package module name context
      def json_class_name
        [hook.class.domain_module, hook.class.qp, self.class.annotation_module.qp, self.class.qp].join('::')
      end
    end
  end
end
