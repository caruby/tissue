require 'jinx/helpers/validation'

module CaTissue
  class ContainerPosition
    add_mandatory_attributes(:parent_container)

    add_attribute_aliases(:parent => :parent_container, :from => :parent_container, :holder => :parent_container,
      :occupant => :occupied_container, :to => :occupied_container)

    # Each ContainerPosition has a container and there is only one position per container.
    set_secondary_key_attributes(:occupied_container)

    set_attribute_inverse(:parent_container, :occupied_positions)

    set_attribute_inverse(:occupied_container, :located_at_position)
    
    qualify_attribute(:parent_container, :fetched)
    
    private
    
    # @raise [Jinx::ValidationError] if the parent is the same as the occupant 
    def validate_local
      super
      if parent == occupant or (parent.identifier and parent.identifier == occupant.identifier) then
         raise Jinx::ValidationError.new("#{self} has a circular containment reference to subcontainer #{occupant}")
      end
    end
  end
end
