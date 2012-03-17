require 'fileutils'
require 'jinx/helpers/os'

# Wustl wraps the +edu.wustl+ package.
module Wustl
  # Logger configures the +edu.wustl+ logger.
  module Logger
    # @quirk caTissue caTissue requires that the log file parent directory exists.
    #   Messages are logged to +client.log+ and +catissuecore.log+ in this directory. If the
    #   directory does not exist, then caTissue raises a FileNotFound exception. The exception
    #   message indicates the log file rather than the log directory. This message is misleading,
    #   since the problem is not that the log file is not found but that the log directory does
    #   not exist. The work-around is to detect the log file from the log4j properties and ensure
    #   that the parent directory exists.
    #
    # @quirk caTissue the caTissue logger must be initialized before caTissue objects are created.
    #   The logger at issue is the caTissue client logger, not the caTissue server logger nor
    #   the caRuby logger. The caTissue logger facade class is edu.wustl.common.util.logger.Logger.
    #   In caTissue 1.1.x, initialization is done with +configure+, in 1.2 with
    #   +LoggerConfig.configureLogger+.
    #
    # @quirk catTissue 1.2 +LoggerConfig.configureLogger+ expects file +log4j.properties+ in the
    #   classpath. However, in 1.2 the client property file is +client_log4j.properties+. The
    #   work-around is to configure an empty log if there is no +log4j.properties+ in the classpath.
    #
    # @quirk caTissue caTissue ignores the +client.log+ and +catissuecore.log+ log level set in
    #   the client jar +log4j.properties+. caTissue spews forth copious cryptic comments,
    #   regardless of the log level.
    #
    # @quirk caTissue 1.1.1 The caTissue client log location is unfortunately hard-coded in a caTissue
    #   configuration file, does not create the parent directory on demand, and issues an obscure error
    #   client message if the directory does not exist. The work-around is to ensure that the working
    #   directory contains a log subdirectory.
    def self.configure
      # Set the configured flag. Configure only once.
      if @configured then return else @configured = true end
      # the log4j properties
      props = Java.load_properties('log4j.properties')
      
      # Ensure that the parent directory exists.
      if props then
        clt_log = props['log4j.appender.clientLog.File']
        ensure_parent_directory_exists(clt_log) if clt_log
        core_log = props['log4j.appender.catissuecoreclientLog.File']
        ensure_parent_directory_exists(core_log) if core_log
      end
      
      # The logger is configured differently depending on the caTissue version.
      log_cls = Java::edu.wustl.common.util.logger.Logger
      if log_cls.respond_to?(:configure) then
        # the caTissue 1.1.2 mechanism
        log_cls.configure("")
      else
        # the caTissue 1.2 mechanism
        cfg_cls = Java::edu.wustl.common.util.logger.LoggerConfig
        # the caTissue 1.2 work-around
        dir = clt_log ? File.dirname(clt_log) : default_log4j_config_directory
        # configure the logger
        cfg_cls.configureLogger(dir)
      end
    end
    
    private
    
    CONF_DIR = File.dirname(__FILE__) + '/../../../conf/wustl'
    
    # Creates the parent directory of the given target path, if necessary.
    #
    # @param [String] path the target path
    def self.ensure_parent_directory_exists(path)
      return if path == '/dev/null' or path == 'NUL'
      File.mkdir(File.dirname(path))
    end
    
    # @return [String] the log4j config to use if one is not found in the classpath
    def self.default_log4j_config_directory
      subdir = Jinx::OS.os_type == :windows ? 'windows' : 'linux'
      File.expand_path(subdir, CONF_DIR)
    end
  end
end