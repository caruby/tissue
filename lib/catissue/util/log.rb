module CaTissue
  private

  # Makes a log subdirectory to avoid a caTissue log initializer error. This method should be called
  # before caTissue start-up.
  #
  # The caTissue log4j location is unfortunately hard-coded in a caTissue client configuration
  # file, does not create the parent directory on demand, and issues an obscure error message if
  # the directory does not exist. This method ensures that the current directory contains a log
  # subdirectory.
  def self.ensure_log4j_directory_exists
    # caTissue alert - avoid caTissue error by creating log subdirectory
    if File.directory?('log') then
      unless File.writable?('log') then
        raise StandardError.new("caTissue log subdirectory #{File.expand_path('log')} is not writable.")
      end
    elsif File.exists?('log') then
      raise StandardError.new("Existing file #{File.expand_path('log')} prevents creation of the required caTissue log subdirectory.")
    else
      begin
        Dir.mkdir('log')
      rescue Exception => e
        raise StandardError.new("Cannot create the log subdirectory required by the caTissue client: #{File.expand_path('log')}.")
      end
    end
  end

  # make the log4j directory, if necessary
  ensure_log4j_directory_exists
end