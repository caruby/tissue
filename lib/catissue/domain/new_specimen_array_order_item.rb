require 'catissue/resource'

module CaTissue
  # import the Java class
  resource_import Java::edu.wustl.catissuecore.domain.NewSpecimenArrayOrderItem

  # The NewSpecimenArrayOrderItem domain class.
  class NewSpecimenArrayOrderItem
    # @quirk caTissue Bug #64: Some domain collection properties not initialized.
    #   Initialize order_items if necessary. 
    #
    # @return [Java::JavaUtil::Set] the items
    def order_items
      getOrderItemCollection or (self.order_items = Java::JavaUtil::LinkedHashSet.new)
    end
    
    # @quirk caTissue Bug #64: Some domain collection properties not initialized.
    #   Initialize distributions if necessary. 
    def distributions
      getDistributionCollection or (self.distributions = Java::JavaUtil::LinkedHashSet.new)
    end

    def initialize
      super
      # jRuby bug? - Java methods not acceesible until respond_to? called; TODO - reconfirm this
      respond_to?(:order_items)
      respond_to?(:distributions)
      # work around caTissue Bug #64
      self.order_items ||= Java::JavaUtil::LinkedHashSet.new
      self.distributions ||= Java::JavaUtil::LinkedHashSet.new
    end
  end
end