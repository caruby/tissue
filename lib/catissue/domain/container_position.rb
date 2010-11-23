module CaTissue
  # import the Java class
  java_import('edu.wustl.catissuecore.domain.ContainerPosition')

  class ContainerPosition
    include Resource

    add_mandatory_attributes(:parent_container)

    add_attribute_aliases(:parent => :parent_container, :holder => :parent_container, :occupant => :occupied_container)

    # Each ContainerPosition has a container and there is only one position per container.
    set_secondary_key_attributes(:occupied_container)

    set_attribute_inverse(:parent_container, :occupied_positions)

    set_attribute_inverse(:occupied_container, :located_at_position)
    
    qualify_attribute(:parent_container, :fetched)
  end
end
