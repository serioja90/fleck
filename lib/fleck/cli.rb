# frozen_string_literal: true

$LOAD_PATH << File.expand_path(__dir__)

require 'thor'

# A container module used to namespace classes and modules related to Fleck
module Fleck
  autoload :NewApp, 'cli/commands/new.rb'

  # Fleck CLI implements a Command Line Interface for easier Fleck app creation and configuration.
  class CLI < Thor
    APP_BOOT_FILE = 'boot.rb'

    def self.exit_on_failure?
      true
    end

    desc 'new APP_NAME', 'Generate a new Fleck application'
    method_option 'no-db', type: :boolean, default: false, desc: 'Do not generate database configuration'
    method_option 'no-kafka', type: :boolean, default: false, desc: 'Do not generate Kafka configuration'
    def new_app(app_name)
      NewApp.new(app_name, options)
    end

    desc 'start', 'Start the Fleck application'
    def start(*_args)
      # Load `config/boot.rb` from application's directory, so that the application could start
      require "#{find_root}/boot.rb"
    end

    private

    def find_root
      # Start from current working directory
      current_path = Dir.pwd

      # Check if current directory is fleck app directory root or go up and check parent directory
      loop do
        # Break when fleck app root found
        break if File.exist?(File.join(current_path, APP_BOOT_FILE))

        # Move one level up (to parent directory)
        current_path = File.expand_path('..', current_path)

        # Break when reached system root directory
        break if current_path == '/'
      end

      # Check if current_path is fleck app root directory and raise and error if
      # fleck app root directory not found
      root = File.exist?(File.join(current_path, APP_BOOT_FILE)) ? current_path : nil
      raise 'Could not find Fleck app root directory' unless root

      # Return fleck app root directory
      Pathname.new File.realpath(root)
    end
  end
end
