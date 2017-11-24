module Fleck
  class Config::Application

    def initialize(root, data = {})
      @root = root
      @config = Configatron::RootStore.new
      @config.configure_from_hash(check(data))
      @config.lock!
    end

    def to_h
      @config.to_h
    end

    def method_missing(name, *args, &block)
      if @config.key? name
        @config[name]
      else
        super(name, *args, &block)
      end
    end

    private

    def check(data)
      cfg = (data || {}).dup

      cfg["name"]        ||= File.basename(File.expand_path(Dir.pwd))
      cfg["timezone"]    ||= "UTC"
      cfg["pidfile"]     ||= "#{@root}/tmp/pids/fleck.pid"
      cfg["logfile"]     ||= "#{@root}/log/fleck.log"
      cfg["loglevel"]    ||= Logger::INFO
      cfg["interactive"] ||= false
      cfg["daemonize"]   ||= false

      # TODO:
      #  - load data from env variables
      #  - name should not be blank
      #  - timezone should have a valid value
      #  - the path to pidfile should exist
      #  - the path to logfile should exist
      #  - convert loglevel to Fixnum if expressed as String
      #  - set logfile to STDOUT constant, if logfile is set to "stdout" or "STDOUT"
      #  - ensure interactive and boolean to be TrueClass or FalseClasss

      return cfg
    end
  end
end