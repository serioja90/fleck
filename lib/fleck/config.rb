require 'configatron/core'

$LOAD_PATH.unshift(File.dirname(__FILE__))

autoload "YAML", "yaml"
autoload "URI", "uri"
autoload "Logger", "logger"

module Fleck
  class Config
    autoload "Application", "config/application"
    autoload "Database", "config/database"
    autoload "Rabbitmq", "config/rabbitmq"

    @default_instance = nil

    RESERVED = ["config_file", "config_paths", "root", "version", "rabbitmq"]

    attr_accessor :config, :search_paths

    def initialize
      @env = nil
      @root = Dir.pwd
      @config = Configatron::RootStore.new

      @config_files = ["fleck.yml", "app.yml", "rabbitmq.yml", "database.yml", "queues.yml"]
      @search_paths = ["./", "config", "configs"]
    end


    def reload_configs!
      @config = Configatron::RootStore.new

      load_configs!
    end


    def load_configs!
      yaml = {"fleck" => {}, "app" => {}, "rabbitmq" => {}, "database" => {}, "queues" => {}}
      cfg = {}

      @config_files.each do |filename|
        @search_paths.each do |path|
          file = File.expand_path(File.join(@root, path, filename))
          if File.exists?(file)
            config = case file
            when "fleck.yml"    then yaml["fleck"]
            when "app.yml"      then yaml["app"]
            when "rabbitmq.yml" then yaml["rabbitmq"]
            when "database.yml" then yaml["db"]
            when "queues.yml"   then yaml["queues"]
            end

            config.merge!(YAML.load_file(file))
          end
        end
      end

      yaml.each do |key, data|
        Config.mix_configs! cfg, data, "app"
        Config.mix_configs! cfg, data, "rabbitmq"
        Config.mix_configs! cfg, data, "db"
        Config.mix_configs! cfg, data, "queues"
      end

      @config.env  = Config.get_env
      @config.root = @root

      # set default configs

      # @config.app.name        = File.basename(File.expand_path(@root))
      # @config.app.timezone    = "UTC"
      # @config.app.pidfile     = "#{@config.root}/tmp/pids/fleck.pid"
      # @config.app.logfile     = "#{@config.root}/log/fleck.log"
      # @config.app.loglevel    = Logger::INFO
      # @config.app.interactive = true

      # if @config._use_db
      #   # set database default configs
      #   @config.db.host    = "127.0.0.1"
      #   @config.db.port    = 5432
      #   @config.db.name    = "postgres"
      #   @config.db.user    = nil
      #   @config.db.pass    = nil
      #   @config.db.sslmode = "disable"
      # end

      # if @config.config_file
      #   # Load configurations from fleck.yml
      #   @config._yml_configs = YAML.load_file(@config.config_file)

      #   # Remove reserved configuration keys
      #   configs = @config._yml_configs.reject{|k,_| k.start_with?("_") || RESERVED.include?(k.downcase)}
      #   @config.configure_from_hash(configs)
      # end

      @config.app.configure_from_hash(Config::Application.new(@root, cfg["app"]).to_h)
      @config.rabbitmq = Config::Rabbitmq.new(cfg["rabbitmq"])
      @config.lock!

      return @config
    end


    def self.method_missing(name, *args, &block)
      @default_instance ||= Fleck::Config.new
      @default_instance.send(name, *args, &block)
    end


    private

    def self.get_env
      env = ENV["FLECK_ENV"].to_s.strip.downcase
      env = ["production", "test", "development"].include?(env) ? env : "development"

      return env
    end


    def self.mix_configs!(target, data, namespace)
      env = Config.get_env

      if data[namespace] and not data[namespace].emtpy?
        target[namespace] ||= {}
        target[namespace].merge!(data[namespace])
      end

      if data[env] and not data[env].empty?
        if data[env][namespace] and not data[env][namespace].empty?
          target[namespace] ||= {}
          target[namespace].merge!(data[env][namespace])
        end
      end

      return target
    end
  end
end