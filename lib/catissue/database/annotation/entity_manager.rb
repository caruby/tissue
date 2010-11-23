require 'caruby/import/java'

module CaTissue
  module Annotation
    # EntityManager dependencies
    java_import('edu.wustl.common.security.exceptions.UserNotAuthorizedException')
    # EntityManager is the caTissue singleton Winnebago object for persisting annotations.
    java_import('edu.common.dynamicextensions.entitymanager.EntityManager')
  end
end