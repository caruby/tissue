require 'catissue/annotation/integration'
require 'catissue/annotation/importer_1_2'
require 'catissue/annotation/integration_metadata_1_2'

module CaTissue
  module Annotation
    # The Annotation Integration mix-in extends the caTissue 1.2 domain RecordEntry classes with methods
    # that tie together the hook and its annotations.
    module Integration_1_2
      include Integration
      
      extend Importer_1_2

      # The caTissue DE Java packages.
      packages 'edu.wustl.catissuecore.domain.deintegration'

      # The annotation integration parent module is the caTissue domain module.
      @parent_importer = CaTissue
      
      # The integration class extension module.
      @metadata_module = IntegrationMetadata_1_2
    end
  end
end