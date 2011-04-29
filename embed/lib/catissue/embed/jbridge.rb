require 'catissue/annotation/annotation'

module CaTissue
  # JBridge is a convenience facade for Java calls into caRuby Tissue.
  module JBridge
    # Creates a new annotation object in the caTissue database.
    #
    # @param [CaTissue::Resource] hook the existing static hook object to annotate
    # @param [CaTissue::Annotation] annotation the annotation object to create
    # @raise [AnnotationError] if the hook object does not have a database identifier
    def create_annotation(hook, annotation)
      unless hook.identifier then
        raise AnnotationError.new("Annotation writer does not support annotation of a caTissue object without an identifier: #{hook}")
      end
      oattr = annotation.class.owner_attribute
      annotation.send(oattr, hook)
      annotation.create
    end
  end
end