require 'caruby/resource'
require 'caruby/domain/resource_module'
require 'catissue/annotation/annotatable'
require 'catissue/wustl/logger'

module CaTissue
  extend CaRuby::ResourceModule
  
  # Set up the caTissue client logger.
  Wustl::Logger.configure

  # The module included by all CaTissue domain classes.
  #
  # A Resource class is extended to support an attribute -> value hash argument
  # to the initialize method. Subclasses which override the initialize method
  # should not include the hash argument, since it is defined by a class
  # instance new method override rather than initialize to work around a JRuby
  # bug. 
  module Resource
    include CaRuby::Resource, CaRuby::IdAlias, Annotatable
    
    # Returns whether each of the given attribute values either equals the
    # respective other attribute value or one of the values is nil or 'Not Specified'.
    #
    # @param [Resource] other the domain object to compare
    # @param [<Symbol>] attributes the  attributes to compare
    # @return [Boolean} whether this domain object is a tolerant match with the other
    #   domain object on the given attributes
    def tolerant_match?(other, attributes)
      attributes.all? { |attr| Resource.tolerant_value_match?(send(attr), other.send(attr)) }
    end

    # Returns the CaTissue::Database which stores this object.
    def database
      CaTissue::Database.instance
    end

    protected

    # Returns the required attributes which are nil for this domain object.
    # Overrides the CaRuby::Resource method to handle the following bug:
    #
    # caTissue alert - Bug #67:  AbstractSpecimen.setActivityStatus
    # is a no-op. The Specimen activityStatus property is incorrectly pulled
    # up to AbstractSpecimen. AbstractSpecimen.activityStatus is marked as
    # mandatory, since it is required for Specimen. However, it is not
    # mandatory, and in fact can't be set, for SpecimenRequirement.
    # Work-around is to add special code to exclude activityStatus from
    # the caRuby SpecimenRequirement missing mandatory attributes validation
    # check.
    def missing_mandatory_attributes
      invalid = super
      # Special case: AbstractSpecimen.setActivityStatus is a no-op.
      if invalid.include?(:activity_status) and CaTissue::SpecimenRequirement === self then
        invalid.delete(:activity_status)
      end
      invalid
    end

    private
    
    # The unspecified value.
    UNSPECIFIED = 'Not Specified'
    
    # @return whether the given value equals the other value or one of the values is nil or 'Not Specified'
    def self.tolerant_value_match?(value, other)
      value == other or unpsecified_value?(value) or unpsecified_value?(other)
    end
    
    # @return whether the given value equals nil or {Resource.UNSPECIFIED}
    def self.unpsecified_value?(value)
      value.nil? or value == UNSPECIFIED
    end
  end

  # The include mix-in module.
  @mixin = Resource

  # The required Java package name.
  @java_package = 'edu.wustl.catissuecore.domain'

  # Extends the given domain class as an #{AnnotatableClass}.
  #
  # @param [Class] klass the class that was added to this domain module
  def self.class_added(klass)
    # Defer loading AnnotatableClass to avoid pulling in Database, which in turn
    # attempts to import java classes before the path is established. Obscure
    # detail, but don't know how to avoid it.
    require 'catissue/annotation/annotatable_class'
    klass.extend(AnnotatableClass)
  end

  # Load the domain class definitions.
  dir = File.join(File.dirname(__FILE__), 'domain')
  load_dir(dir)
end

