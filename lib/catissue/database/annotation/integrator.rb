module CaTissue
  module Annotation
    # An Integrator fetches and saves CaTissue hook-annotation associations.
    class Integrator
      # @return [:prefix, :postfix] whether integration is performed before or after
      #   the annotation save
      attr_reader :order

      # @param [Module] the annotation module
      def initialize(mod)
        re_cls = mod.record_entry_class
        # the integration delegate
        @dlg = if re_cls then
          require 'catissue/database/annotation/record_entry_integrator'
          @order = :prefix
          RecordEntryIntegrator.new(mod)
        else
          require 'catissue/database/annotation/integration_service'
          @order = :postfix
          IntegrationService.new
        end
      end

      # Associates the given hook domain object to the annotation.
      #
      # @param [Annotatable] hook the hook entity 
      # @param [Annotation] annotation the annotation entity 
      def associate(hook, annotation)
        logger.debug { "Associating annotation #{annotation} to owner #{hook}..." }
        # the hook must have an identifier
        if hook.identifier.nil? then
          raise CaRuby::DatabaseError.new("Static hook object #{hook} referenced by annotation #{annotation} does not have an identifier")
        end
        @dlg.associate(hook, annotation)
      end
    end
  end
end