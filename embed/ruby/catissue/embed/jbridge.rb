require 'singleton'

require 'rubygems'
gem 'caruby-tissue'
require 'catissue'
require 'catissue/annotation/annotation'

module CaTissue
  # JBridge is a convenience facade for Java calls into caRuby Tissue.
  class JBridge
    include Singleton
    
    # Creates a new annotation object in the caTissue database.
    #
    # @param [CaTissue::Resource] hook the existing static hook object to annotate
    # @param [CaTissue::Annotation] annotation the annotation object to create
    # @raise [AnnotationError] if the hook object does not have a database identifier
    def create_annotation(hook, annotation)
      # validate the arguments
      if hook.nil? then raise ArgumentError.new("Annotated caTissue object is missing") end
      if annotation.nil? then raise ArgumentError.new("Annotation caTissue object is missing") end
      # the annotated object must exist in the database
      unless hook.identifier then
        raise AnnotationError.new("Annotation writer does not support annotation of a caTissue object without an identifier: #{hook}")
      end
      # load the caRuby annotations if necessary
      hook.class.ensure_annotations_loaded
      # the annotation => hook attribute
      attr = annotation.class.proxy_attribute
      if attr.nil? then
        raise AnnotationError.new("The annotation class #{annotation.class} does not have an attribute that references a #{hook.class.qp}")
      end
      # set the annotation hook reference
      annotation.set_attribute(attr, hook)
      # create the annotation in the database
      annotation.create
    end
  end
end