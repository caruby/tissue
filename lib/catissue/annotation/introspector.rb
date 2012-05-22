module CaTissue
  module Annotation
    module Introspector
      private
      
      # Augments +Jinx::Introspector.create_java_attribute+ to accomodate the
      # following caTissue anomaly:
      #
      # @quirk caTissue DE annotation collection attributes are often misnamed,
      #   e.g. +histologic_grade+ for a +HistologicGrade+ collection attribute.
      #   This is fixed by adding a pluralized alias, e.g. +histologic_grades+.
      #
      # @return [Symbol] the new attribute symbol
      def create_java_property(pd)
        # the new property
        prop = super
        # alias a misnamed collection attribute, if necessary
        if prop.collection? then
          name = prop.attribute.to_s
          if name.singularize == name then
            aliaz = name.pluralize.to_sym
            if aliaz != name then
              logger.debug { "Adding annotation #{qp} alias #{aliaz} to the misnamed collection property #{prop}..." }
              delegate_to_property(aliaz, prop)
            end
          end
        end
        prop
      end
    end
  end
end