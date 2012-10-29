require 'jinx/resource'

module CaTissue
  module Annotation
    # DEIntegration encapsulates the auxiliary DE integration package in caTissue 1.2.
    #
    # @quirk caTissue 1.2 caTissue 1.2 introduces the auxiliary DE integration package
    #   +edu.wustl.catissuecore.domain.deintegration+ holding the RecordEntry DE proxy
    #   classes.
    module DEIntegration
      include Jinx::Resource
      
      extend Jinx::Importer

      # The caTissue Java package name.
      packages 'edu.wustl.catissuecore.domain.deintegration'
      
      # Returns the domain DE integration proxy class with the given name.
      #
      # @param [String] name the annotated hook class name
      # @return [Class, nil] the hook proxy class, or nil if none defined
      def self.proxy(name)
        begin
          const_get(name)
        rescue NameError
          nil
        end
      end
    end
  end
end