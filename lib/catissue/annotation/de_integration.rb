require 'jinx/resource'

module CaTissue
  module Annotation
    # DEIntegration encapsulates the auxiliary DE integration package in caTissue 1.2 and higher.
    module DEIntegration
      include Jinx::Resource

      # The caTissue Java package name.
      packages 'edu.wustl.catissuecore.domain.deintegration'
      
      # @param [String] name the annotated hook class name
      # @return [Class, nil] the hook proxy class, or nil if none defined
      def self.proxy(name)
        const_get(name) rescue nil
      end
    end
  end
end