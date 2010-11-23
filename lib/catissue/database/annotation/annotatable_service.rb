require 'delegate'
require 'caruby/database/persistence_service'

module CaTissue
  module Annotation
    # An AnnotatableService queries and saves domain classes which hold annotation attributes.
    class AnnotatableService < DelegateClass(CaRuby::PersistenceService)
      def initialize(database, app_service, integration_service)
        super(app_service)
        @database = database
        @integration_service = integration_service
      end
#
#       def create(obj)
#        super
#        # TODO - refactor CaRuby::Database to remove Annotation cases; iterate over each annotation attribute here
#      end
#
#      def update(obj)
#        super
#        # TODO - refactor CaRuby::Database to remove Annotation cases; iterate over each annotation attribute here
#      end
    end
  end
end