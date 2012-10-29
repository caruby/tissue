require 'catissue/annotation/integration_metadata'

module CaTissue
  module Annotation
    # The Annotation Integration mix-in extends the domain RecordEntry classes with methods
    # that tie together the hook and its annotations.
    module Integration
      include Jinx::Resource
      
      extend Jinx::Importer

      # The caTissue DE Java packages.
      packages 'edu.wustl.catissuecore.domain.deintegration', 'edu.common.dynamicextensions.domain.integration'

      # The annotation integration parent module is the caTissue domain module.
      @parent_importer = CaTissue
      
      # The integration class extension module.
      @metadata_module = IntegrationMetadata
    end
  end
end
