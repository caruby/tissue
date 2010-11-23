module CaTissue
  # explicitly import AbstractDomainObject, since it is not in the default CaTissue package and therefore can't be auto-imported
  java_import('edu.wustl.common.domain.AbstractDomainObject')

  class AbstractDomainObject
    include Resource
  end
end