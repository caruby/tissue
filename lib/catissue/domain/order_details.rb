

module CaTissue
  java_import('edu.wustl.catissuecore.domain.OrderDetails')

  # The OrderDetails domain class.
  class OrderDetails
    include Resource
    
    # caTissue alert - Bug #64: Some domain collection properties not initialized.
    # Initialize order_items if necessary. 
    #
    # @return [Java::JavaUtil::Set] the items
    def order_items
      getOrderItemCollection or (self.order_items = Java::JavaUtil::LinkedHashSet.new)
    end
    
    def initialize(params=nil)
      super
      respond_to?(:order_items)
      # caTissue alert - work around caTissue Bug #64
      self.order_items ||= Java::JavaUtil::LinkedHashSet.new
    end
  end
end