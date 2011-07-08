

module CaTissue
  resource_import Java::edu.wustl.catissuecore.domain.OrderDetails

  # The OrderDetails domain class.
  class OrderDetails
    # @quirk caTissue Bug #64: Some domain collection properties not initialized.
    #   Initialize order_items if necessary. 
    #
    # @return [Java::JavaUtil::Set] the items
    def order_items
      getOrderItemCollection or (self.order_items = Java::JavaUtil::LinkedHashSet.new)
    end
    
    def initialize
      super
      respond_to?(:order_items)
      self.order_items ||= Java::JavaUtil::LinkedHashSet.new
    end
  end
end