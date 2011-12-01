require 'caruby/domain'
require 'catissue/annotation/annotatable_class'

# CaTissue wraps the caTissue Java API.
module CaTissue
  # @param [<String>] nodes the path components relative to the caRuby Tissue source directory
  # @return [String] the file path to the specified path components
  def self.path(*nodes)
    root = File.dirname(__FILE__) + '/..'
    File.expand_path(File.join(*nodes), root)
  end
  
  # @quirk caTissue 1.2 the caTissue API class path is sensitive to order in subtle ways that
  #   caTissue 1.1.2 is not. The caTissue client +build.xml+ defines a +cp+ classpath 
  #   property which was used to run a caTissue 1.1.1 example.
  #
  #   However, the example was removed in caTissue 1.1.2. As of 1.1.2, the +cp+ property is no
  #   longer referenced in the client +build.xml+. Rather, the classpath is defined inline
  #   in the task with a small but important change: +cp+ placed the config directories
  #   before the jar files, whereas the inline definition placed the configs after the jars.
  #
  #   This difference does not present a problem in caTissue 1.1.2, but the confusion was
  #   carried over to caTissue 1.2 where it does cause a problem. Unlike caTissue 1.1.2,
  #   in 1.2 the +DynamicExtension.jar+ is redundantly included in both the client and the
  #   declient lib. Furthermore, +DynamicExtension.jar+ contains an invalid and unnecessary
  #   +remoteServices.xml+, which references a non-existent +RemoteSDKApplicationService+.
  #
  #   If the caTissue path is defined with the jars preceding the configs, then in 1.2 an
  #   obscure +PropertyAccessExceptionsException+ exception is raised indicating that
  #   +RemoteSDKApplicationService+ is an invalid class name. The cause is the classpath
  #   precedence of jars prior to configs.
  #
  #   The caRuby FAQ shows an example +~/.catissue+ +path+ property that was originally
  #   borrowed from the caTissue 1.1.1 client example. This incorrect precedence was a time
  #   bomb that exploded in 1.2. This 1.2 regression is now noted in the FAQ.
  #
  # @quirk caTissue 1.2 per the caTissue API client Ant build file, the +catissuecore.jar+
  #   should not be included in the client class path, even though it is in the client lib
  #   directory.
  #
  # @param [Module] mod the resource mix-in module to extend with metadata capability
  def self.resource_mixin=(mod)
    # Enable the resource metadata aspect.
    CaRuby::Domain.extend_module(self, :mixin => mod, :metadata => AnnotatableClass, :package => PKG, :directory => SRC_DIR)
    # TODO - somehow filter the path to exclude catissuecore.jar.
  end
  
  private
  
  # The required Java package name.
  PKG = 'edu.wustl.catissuecore.domain'
  
  # The domain class definitions.
  SRC_DIR = File.dirname(__FILE__) + '/domain'
end

