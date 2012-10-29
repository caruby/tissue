module CaTissue
  # The Initializer mix-in works around a caTissue initialization bug.
  module Initializer
    # Sets each nil collection property value to an empty collection.
    #
    # @quirk caTissue Bug #64 - Java collection type property values to an empty
    #   collection. In many cases, the property type is abstract. Since this bug
    #   was reported in caTissue 1.1.1, each new release has introduced new
    #   regressions. The bug occurs in at least the following caTissue classes:
    #   * SpecimenCollectionGroup consent_tier_statuses
    #   * StorageType holds_storage_types, holds_specimen_array_types and holds_specimen_classes
    #   * StorageContainer specimen_positions, holds_storage_types, holds_specimen_array_types and holds_specimen_classes
    #   * Participant medical_identifiers
    #
    #   The generic work-around is to initialize each caTissue domain object
    #   collection property with a nil value to a default value as follows:
    #   * If the property is concrete, then the default value is a new instance of
    #     the property type.
    #   * Otherwise, if the property is a Java List, then the default value is a
    #     new Java ArrayList.
    #   * Otherwise, the default value is a new Java LinkedHashSet.
    def post_initialize
      super
      self.class.properties.each do |prop|
        if prop.collection? and prop.java_property? and send(prop.java_reader).nil? then
          value = default_collection_value(prop.java_wrapper_class)
          send(prop.java_writer, value)
        end
      end
    end

    private
    
    # @param [Class] klass the Java collection class, which may be abstract
    # @return an instance of the class
    # @see #initialize
    def default_collection_value(klass)
      if klass.abstract? then
        klass <= Java::java.util.List ? Java::JavaUtil::ArrayList.new : Java::JavaUtil::LinkedHashSet.new
      else
        klass.new
      end
    end
  end
end
