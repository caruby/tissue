module CaTissue
  class CheckInCheckOutEventParameter
    # The check-in/check-out status permissible values.
    module Status
      CHECKED_OUT = 'CHECK OUT'
      CHECKED_IN = 'CHECK IN'
    end

    add_attribute_aliases(:status => :storage_status, :state => :storage_status)

    add_mandatory_attributes(:storage_status)
  end
end