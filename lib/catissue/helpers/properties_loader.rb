module CaTissue
  # The caTissue classpath and connection parameters properties loader mix-in.
  module PropertiesLoader
    class ConfigurationError < StandardError; end
    
    # @return [{Symbol => [String, <String>]}] the application properties
    def properties
      @properties ||= load_properties
    end
    
    private

    # Loads the caTissue classpath and connection properties.
    def load_properties
      # the properties file
      file = default_properties_file
      # the access properties
      props = file && File.exists?(file) ? load_properties_file(file) : {}
      # Load the Java application jar path.
      path = props[:classpath] || props[:path] || infer_classpath
      Java.expand_to_class_path(path) if path
      # Get the application login properties from the remoteService.xml, if necessary.
      unless props.has_key?(:host) or props.has_key?(:port) then
        url = remote_service_url
        if url then
          host, port = url.split(':')
          props[:host] = host
          props[:port] = port
        end
      end
      props
    end
    
    def remote_service_url
      file = $CLASSPATH.detect_value do |loc|
        if File.directory?(loc) then
          f = File.expand_path('remoteService.xml', loc)
          f if File.exists?(f)
        end
      end
      if file then
        url = File.new(file).detect_value { |line| line[%r{http://(.*)/catissuecore/http/remoteService}, 1] }
        logger.debug { "Inferred the access url #{url} from #{file}." } if url
        url
      end                                                   
    end
    
    def load_properties_file(file)
      props = {}
      logger.info("Loading application properties from #{file}...")
      File.open(file).each do |line|
        # match the tolerant property definition
        match = PROP_DEF_REGEX.match(line.chomp.strip) || next
        # the property [name, value] tokens
        tokens = match.captures
        pname = tokens.first.to_sym
        # :path is deprecated; if there is a :path entry, then
        # set :classpath with the :path value instead.
        name = pname == :path ? :classpath : pname
        value = tokens.last
        # capture the property
        props[name] = value
      end
      props
    end

    # The property/value matcher, e.g.:
    #   host: jacardi
    #   host = jacardi
    #   host=jacardi
    #   name: J. Edgar Hoover
    # but not:
    #   # host: jacardi
    # The captures are the trimmed property and value.
    PROP_DEF_REGEX = /^(\w+)(?:\s*[:=]\s*)([^#]+)/
  
    # @return [String] the default application properties file, given by +~/.+_name_,
    #   where _name_ is the underscore unqualified module name, e.g. +~/.catissue+
    #   for module +CaTissue+
    def default_properties_file
      home = ENV['HOME'] || ENV['USERPROFILE'] || '~'
      file = File.expand_path('.catissue', home)
      file if File.exists?(file)
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
    def infer_classpath
      
      
      ENV['CATISSUE_CLIENT_HOME'] = '/usr/local/src/catissue/build/caTissue_Suite_API_Client_v1.2_Installable'
      
      
      dir = ENV['CATISSUE_CLIENT_HOME'] || '.'
      logger.info("Inferring the class path from directory #{dir}...")
      # Hunt for the client directories
      clt_dir = client_directory(dir, 'caTissueSuite_Client')
      de_dir = client_directory(dir, 'catissue_de_integration_client')
      dirs = [client_subdirectory(clt_dir, 'conf'),
        client_subdirectory(de_dir, 'conf'),
        client_subdirectory(clt_dir, 'lib'),
        client_subdirectory(de_dir, 'lib')
      ]
      # caTissue 1.1.2 has an extra directory.
      clt_lib = File.expand_path('lib', dir)
      dirs << clt_lib if File.directory?(clt_lib)
      # Make a semi-colon separated path string.
      path = dirs.join(';')
      logger.info("Inferred the class path #{path}.")
      path
    end
         
    # @param [String] dir the caTissue install parent directory
    # @param [<String>] subdirs the possible client subdirectory locations 
    def client_directory(dir, *subdirs)
      subdirs.each do |subdir|
        clt_dir = File.expand_path(subdir, dir)
        return clt_dir if File.directory?(clt_dir) 
      end
      raise ConfigurationError.new("caTissue client subdirectory not found in installation directory #{dir}: #{subdirs.to_series('or')}")
    end
    
    def client_subdirectory(dir, subdir)
      clt_subdir = File.expand_path(subdir, dir)
      unless File.directory?(clt_subdir) then
        raise ConfigurationError.new("caTissue client directory #{dir} does not include the #{subdir} subdirectory.")
      end
      clt_subdir
    end
  end
end