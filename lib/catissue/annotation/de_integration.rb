module CaTissue
  module Annotation
    # DEIntegration encapsulates the +edu.wustl.catissuecore.domain.deintegration+ package in caTissue 1.2 and higher.
    module DEIntegration
      # @param [Symbol] the referenced constant
      # @return [Class] yet another undocumented special-purpose association record entry class
      #   which associates the given hook proxy class symbol to an annotation
      def self.const_missing(symbol)
        begin
          java_import [PKG, symbol].join('.')
        rescue Exception
          super
        end
      end
      
      private
  
      # The auxiliary record entry class Java package name.
      PKG = 'edu.wustl.catissuecore.domain.deintegration'
    end
  end
end