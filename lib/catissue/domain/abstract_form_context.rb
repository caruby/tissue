module CaTissue
  class AbstractFormContext
    # @quirk caTissue The AbstractFormContext +record_entries+ reference is unnecessary and expensive to fetch
    #    on demand. The +record_entries+ property is not useful to the API in practice, and is therefore
    #    occluded by caRuby.
    remove_attribute(:record_entries)
  end
end
