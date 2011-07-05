require 'caruby/domain'

module CaTissue
  module Annotation
    # DEIntegration encapsulates the +edu.wustl.catissuecore.domain.deintegration+ package in caTissue 1.2 and higher.
    module DEIntegration
      # @param [Symbol] the referenced constant
      # @return [Class] yet another undocumented special-purpose association record entry class
      #   which associates the given hook proxy class symbol to an annotation
      def self.const_missing(symbol)
        name = [PKG, symbol].join('.')
        logger.debug { "Importing DE integration proxy Java class #{name}..." }
        begin
          java_import name
        rescue NameError
          super
        end
      end
      
      # @param [String] name the annotated hook class name
      # @return [Class, nil] the hook proxy class, or nil if none defined
      def self.proxy(name)
        const_get(name.to_sym) rescue nil
      end
    
      private
  
      # The auxiliary record entry class Java package name.
      PKG = 'edu.wustl.catissuecore.domain.deintegration'
    end
  end
end