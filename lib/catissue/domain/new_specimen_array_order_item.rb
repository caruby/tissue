module CaTissue
  # The NewSpecimenArrayOrderItem domain class.
  class NewSpecimenArrayOrderItem
    # @quirk caTissue Bug #64: order items collection property is not initialized to an empty set
    #    in the Java constructor. Initialize it to a +LinkedHashSet+ in caRuby. 
    #
    # @return [Java::JavaUtil::Set] the items
    def order_items
      getOrderItemCollection or (self.order_items = Java::JavaUtil::LinkedHashSet.new)
    end
    
   # @quirk caTissue Bug #64: distributions collection property is not initialized to an empty set
    #    in the Java constructor. Initialize it to a +LinkedHashSet+ in caRuby.
    def distributions
      getDistributionCollection or (self.distributions = Java::JavaUtil::LinkedHashSet.new)
    end

    def initialize
      super
      # @quirk JRuby order_items and distributions property methods are not accessible until
      # respond_to? is called.
      respond_to?(:order_items)
      respond_to?(:distributions)
      # work around caTissue Bug #64
      self.order_items ||= Java::JavaUtil::LinkedHashSet.new
      self.distributions ||= Java::JavaUtil::LinkedHashSet.new
    end
  end
end