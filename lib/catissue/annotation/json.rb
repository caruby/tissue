module CaTissue
  module Annotation
    module JSON
      private
      
      # The JSON class name must be scoped by the Resource package module, not the
      # Java package, in order to recognize the Jinx::Resource JSON hooks. For example,
      # the +Participant+ +LabAnnotation+ class name is
      # +CaTissue::Participant::Clinical::LabAnnotation+. 
      #
      # @return [String] the class name qualified by the Resource package module name
      #   context
      def json_class_name
        mod = self.class.annotation_module
        [mod.hook.domain_module, mod.hook, mod, self.class].map { |m| m.name.demodulize }.join('::')
      end
    end
  end
end
