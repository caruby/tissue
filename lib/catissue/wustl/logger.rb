# Wustl wraps the +edu.wustl+ package.
module Wustl
  # Logger configures the +edu.wustl+ logger.
  module Logger
    # @quirk caTissue the caTissue logger must be initialized before caTissue objects are created.
    #   The logger at issue is the caTissue client logger, not the caTissue server logger nor
    #   the caRuby logger. The caTissue logger facade class is edu.wustl.common.util.logger.Logger.
    #   In caTissue 1.1.x, initialization is done with +configure+, in 1.2 with
    #   +LoggerConfig.configureLogger+.
    #
    # @quirk catTissue +LoggerConfig.configureLogger+ expects file +log4j.properties+ in the class
    #   path. However, in 1.2 the client property file is +client_log4j.properties+. Work-around is
    #   as follows:
    #   * copy this file into the caRuby Tissue distribution as +conf/wustl/log4.properties+
    #   * add +conf/wustl+ to the classpath.
    #   * call +LoggerConfig.configureLogger+ with the config directory as an argument
    #
    # @quirk caTissue 1.1.2 The caTissue client log location is unfortunately hard-coded in a caTissue
    #   configuration file, does not create the parent directory on demand, and issues an obscure error
    #   client message if the directory does not exist. The work-around is to ensure that the working
    #   directory contains a log subdirectory.
    def self.configure
      # Set the configured flag. Configure only once.
      if @configured then return else @configured = true end
      ## make the required log subdirectory in the working directory
      # ensure_log_directory_exists
      # the caTissue 1.1.x mechanism
      log_cls = Java::edu.wustl.common.util.logger.Logger
      if log_cls.respond_to?(:configure) then
        log_cls.configure("")
      else
        # the caTissue 1.2 mechanism
        cfg_cls = Java::edu.wustl.common.util.logger.LoggerConfig
        dir = File.join(File.dirname(__FILE__), '..', '..', '..', 'conf', 'wustl')
        cfg_cls.configureLogger(dir)
      end
    end
  
    private

    # Makes a +./log+ subdirectory to avoid a caTissue log initializer error. This method should be called
    # before configuring the logger.
    #
    # @quirk caTissue avoid caTissue error by creating log subdirectory.
    def self.ensure_log_directory_exists
      if File.directory?('log') then
        unless File.writable?('log') then
          raise StandardError.new("caTissue log subdirectory #{File.expand_path('log')} is not writable")
        end
      elsif File.exists?('log') then
        raise StandardError.new("Existing file #{File.expand_path('log')} prevents creation of the required caTissue log subdirectory")
      else
        begin
          Dir.mkdir('log')
        rescue Exception => e
          raise StandardError.new("Cannot create the log subdirectory required by the caTissue client: #{File.expand_path('log')}")
        end
      end
    end
  end
end