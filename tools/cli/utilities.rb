autoload :ERB, 'erb'
autoload :FileUtils, 'fileutils'
autoload :Open3, 'open3'

module Cli::Utilities
  include Thor::Actions

  # Run a shell command
  # command: the command to execute
  # wd: working directory (che command will be run within the current location, if unset)
  def run(command, wd: nil)
    process = nil
    say "#{command}", :blue

    cmd = wd ? "cd #{wd} && #{command}" : command

    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      stdout.each do |line|
        say line, :green
        yield line if block_given?
      end

      stderr.each do |line|
        say line, :red
      end

      process = wait_thr.value
    end

    fail "`#{command}`: #{process}." unless process.success?

    process
  end


  # Cancel installation
  def cancel!
    say "[Canceled]", :red
    exit 0
  end


  def method_missing(name, *args, &block)
    if FileUtils.respond_to?(name)
      FileUtils.send(name, *args, &block)
    else
      super(name, *args, &block)
    end
  end
end