require 'caruby/resource'
require 'caruby/domain/attribute_initializer'
require 'caruby/domain/resource_module'
require 'catissue/annotation/annotatable'

module CaTissue
  extend CaRuby::ResourceModule

  # The module included by all CaTissue domain classes.
  module Resource
    include CaRuby::Resource, CaRuby::IdAlias, CaRuby::AttributeInitializer, Annotatable

    # Adds the given domain class to the CaTissue domain module.
    #
    # @param [Class] klass the included class
    def self.included(klass)
      super
      CaTissue.add_class(klass)
      # defer loading AnnotatableClass to avoid pulling in Database, which in turn
      # attempts to import java classes before the path is established. obscure
      # detail, but don't know how to avoid it.
      require 'catissue/annotation/annotatable_class'
      klass.extend(AnnotatableClass)
    end
    
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

  # Load the domain class definitions.
  dir = File.join(File.dirname(__FILE__), 'domain')
  load_dir(dir)
end

module JavaLogger
  # caTissue alert - the caTissue logger must be initialized before caTissue objects are created.
  # The logger at issue is the caTissue client logger, not the caTissue server logger nor
  # the caRuby logger. The caTissue logger facade class is edu.wustl.common.util.logger.Logger,
  # which is wrapped in Ruby as EduWustlCommonUtilLogger::Logger. TODO - isolate and report.
  Java::EduWustlCommonUtilLogger::Logger.configure("")
end
