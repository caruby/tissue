require 'fileutils'
require 'caruby/helpers/os'

# Wustl wraps the +edu.wustl+ package.
module Wustl
  # Logger configures the +edu.wustl+ logger.
  module Logger
    # @quirk caTissue caTissue requires that a +log+ directory exist in the working directory.
    #   Messages are logged to +client.log+ and +catissuecore.log+ in this directory. If the
    #   directory does not exist, then caTissue raises a FileNotFound exception. The exception
    #   message indicates the log file rather than the log directory. This message is misleading,
    #   since the problem is not that the log file is not found but that the log directory does
    #   not exist.
    #
    # @quirk caTissue caTissue ignores the +client.log+ and +catissuecore.log+ log level set in
    #   the client jar +log4j.properties+. caTissue spews forth copious cryptic worthless comments,
    #   regardless of the log level. The 1.2 work-around is to redirect log messages to +/dev/null+
    #   in non-Windows systems, +NUL+ in Windows.
    #
    # @quirk caTissue the caTissue logger must be initialized before caTissue objects are created.
    #   The logger at issue is the caTissue client logger, not the caTissue server logger nor
    #   the caRuby logger. The caTissue logger facade class is edu.wustl.common.util.logger.Logger.
    #   In caTissue 1.1.x, initialization is done with +configure+, in 1.2 with
    #   +LoggerConfig.configureLogger+.
    #
    # @quirk catTissue 1.2 +LoggerConfig.configureLogger+ expects file +log4j.properties+ in the class
    #   path. However, in 1.2 the client property file is +client_log4j.properties+. Work-around is
    #   as follows:
    #   * copy this file into the caRuby Tissue distribution as +conf/wustl/log4.properties+
    #   * add +conf/wustl+ to the classpath.
    #   * call +LoggerConfig.configureLogger+ with the config directory as an argument
    #
    # @quirk caTissue 1.1.1 The caTissue client log location is unfortunately hard-coded in a caTissue
    #   configuration file, does not create the parent directory on demand, and issues an obscure error
    #   client message if the directory does not exist. The work-around is to ensure that the working
    #   directory contains a log subdirectory.
    def self.configure
      # Set the configured flag. Configure only once.
      if @configured then return else @configured = true end
      log_cls = Java::edu.wustl.common.util.logger.Logger
      if log_cls.respond_to?(:configure) then
        # the caTissue 1.1.2 mechanism
        log_cls.configure("")
      else
        # the caTissue 1.2 mechanism
        cfg_cls = Java::edu.wustl.common.util.logger.LoggerConfig
        subdir = CaRuby::OS.os_type == :windows ? 'windows' : 'linux'
        dir = File.expand_path(subdir, CONF_DIR)
        cfg_cls.configureLogger(dir)
      end
    end
    
    private
    
    CONF_DIR = File.dirname(__FILE__) + '/../../../conf/wustl'
  end
end