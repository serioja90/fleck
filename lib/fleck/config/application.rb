module Fleck
  class Config::Application

    def initialize(root, env, data = {})
      @root = root
      @env = env
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

      cfg.merge!(load_configs_from_env)

      cfg["name"]        ||= File.basename(File.expand_path(Dir.pwd))
      cfg["timezone"]    ||= ENV["TZ"] || "UTC"
      cfg["pidfile"]     ||= "#{@root}/tmp/pids/fleck_#{@env}.pid"
      cfg["logfile"]     ||= "#{@root}/log/#{@env}.log"
      cfg["loglevel"]    ||= Logger::INFO
      cfg["interactive"] ||= false
      cfg["daemonize"]   ||= false

      check_type_of cfg["name"],        name: "app.name",        expected: String
      check_type_of cfg["timezone"],    name: "app.timezone",    expected: String
      check_type_of cfg["pidfile"],     name: "app.pidfile",     expected: String
      check_type_of cfg["logfile"],     name: "app.logfile",     expected: String
      check_type_of cfg["loglevel"],    name: "app.loglevel",    expected: [String, Fixnum]
      check_type_of cfg["interactive"], name: "app.interactive", expected: [TrueClass, FalseClass]
      check_type_of cfg["daemonize"],   name: "app.daemonize",   expected: [TrueClass, FalseClass]

      raise "Invalid config: app.name cannot be blank!"        if is_blank?(cfg["name"])
      raise "Invalid config: app.timezone cannot be blank!"    if is_blank?(cfg["timezone"])
      raise "Invalid config: app.pidfile cannot be blank!"     if is_blank?(cfg["pidfile"])
      raise "Invalid config: app.logfile cannot be blank!"     if is_blank?(cfg["logfile"])
      raise "Invalid config: app.loglevel cannot be blank!"    if is_blank?(cfg["loglevel"])

      # Ensure timezone to be uppercase
      cfg["timezone"] = cfg["timezone"].upcase

      # Set logfile to STDOUT when specified
      if cfg["logfile"].upcase.strip == "STDOUT"
        cfg["logfile"] = STDOUT
      end

      # Translate loglevel from String to Fixnum
      if cfg["loglevel"].is_a?(String)
        cfg["loglevel"] = case cfg["loglevel"].downcase
        when "debug" then Logger::DEBUG
        when "info"  then Logger::INFO
        when "warn"  then Logger::WARN
        when "error" then Logger::ERROR
        when "fatal" then Logger::FATAL
        else
          Logger::UNKNOWN
        end
      end

      return cfg
    end


    # Extract configs from environment variable
    def load_configs_from_env
      configs = {}

      vars = ENV.select{|k,_| k.start_with?("APP_") || k.start_with?("FLECK_APP_") }
      vars.each do |key, value|
        next if key.end_with?("_")

        set_value_at_path!(configs, key.gsub(/(^APP_|^FLECK_APP_)/, "").split("_"), convert_value_type(value))
      end

      return configs
    end


    # Set the value at the specified path in the target hash
    def set_value_at_path!(target = {}, path = [], value)
      key = path.shift.to_s.downcase

      return if key.empty?

      if path.empty?
        # this is the last item
        target[key] = value
      else
        # this is not the last item in the path
        target[key] ||= {}
        set_value_at_path!(target[key], path, value)
      end
    end


    # Check if items is blank
    def is_blank?(item)
      return true if item.nil?
      return true if (item.is_a?(Array) || item.is_a?(String)) && item.empty?
      return false
    end


    # Guess value type and return a converted result
    def convert_value_type(value)
      case value
      when /^(yes|true)$/  then true
      when /^(no|false)$/  then false
      when /^\d+$/         then value.to_i
      when /^\d+(\.\d+)?$/ then value.to_f
      else
        value
      end
    end


    # Check if value has a correct type
    def check_type_of(value, name: "config", expected: Nil)
      if (expected.is_a?(Array) && expected.include?(value.class)) || (expected.is_a?(Class) && value.is_a?(expected))
        value
      else
        raise "Invalid type for ##{name} = #{value.inspect}: #{expected} expected"
      end
    end
  end
end