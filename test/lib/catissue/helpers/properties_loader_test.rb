require File.dirname(__FILE__) + '/../../../helpers/test_case'

# This class verifies that the classpath property is loaded or inferred.
# Manually verify that the classpath is inferred by removing the
# +~/.catissue+ file and setting the +CATISSUE_CLIENT_HOME+ env var.
class PropertiesLoaderTest < Test::Unit::TestCase
  def setup
    # the path before loading caTissue
    before = $CLASSPATH.to_s
    # Induce application property load by referencing the properties.
    CaTissue::Specimen
    # the difference between the path before and after loading caTissue
    @path = $CLASSPATH.to_s[before.length..-1]
  end
  
  def test_path
    assert_not_nil(@path, "path property was not loaded")
  end
end
