# frozen_string_literal: true

$LOAD_PATH << File.expand_path(__dir__)

require 'configatron/core'
require 'erb'
require 'yaml'

module Fleck
  class Application
    # A class to define application configurations.
    class Configuration
      attr_reader :env, :root

      def initialize
        @args = ARGV.dup
        @store = {}

        detect_environment!
        find_root!
        detect_command!(@args.shift)

        set_configs!

        puts inspect
      end

      def app?
        @command == 'start'
      end

      def console?
        @command == 'console' || command == 'c'
      end

      def config_for(name, config_file, warnings: false)
        unless File.exist?(config_file)
          warn "WARNING: #{config_file.inspect} config file was not found" if warnings
          return
        end

        interpolated_config = ERB.new(File.read(config_file)).result
        config = YAML.safe_load(interpolated_config, aliases: true)
        @store[name] ||= Configatron::RootStore.new
        @store[name].configure_from_hash(config[env]) if config[env]
      end

      protected

      def detect_environment!
        @env = ENV['FLECK_ENV'] || ENV['RACK_ENV'] || 'development'
      end

      def find_root!
        @root = Fleck.find_app_root
      end

      def detect_command!(command)
        @command = command.split(':').first if command
        @subcommand = command.split(':')[1] if command&.include?(':')
      end

      def set_configs!
        config_for(:main, "#{root}/config/app.example.yml", warnings: true)
        config_for(:main, "#{root}/config/app.yml")

        config_for(:rmq, "#{root}/config/rabbitmq.example.yml", warnings: true)
        config_for(:rmq, "#{root}/config/rabbitmq.yml")

        config_for(:db, "#{root}/config/database.example.yml", warnings: true)
        config_for(:db, "#{root}/config/database.yml")

        config_for(:kafka, "#{root}/config/kafka.example.yml", warnings: true)
        config_for(:kafka, "#{root}/config/kafka.yml")
      end
    end
  end
end
