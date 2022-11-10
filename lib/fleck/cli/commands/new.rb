# frozen_string_literal: true

module Fleck
  # Implements the command for new Fleck app creation.
  class NewApp < Thor
    include Thor::Actions
    attr_accessor :app_name, :options, :description

    def self.source_root
      File.expand_path('new/templates', __dir__)
    end

    def initialize(app_name, options)
      super()

      @app_name = app_name
      @options = options
      @description = "#{app_name} app"
      self.destination_root = "#{Dir.pwd}/#{app_name}"
      create_app!
    end

    private

    def snake_case_name
      Thor::Util.snake_case(app_name)
    end

    def create_app!
      say "Going to generate a new Fleck app #{app_name.inspect}..."
      self.description = ask('Description: ', Thor::Shell::Color::BLUE, default: description)

      create_app_directories
      generate_files
      install_gems

      Dir.chdir(destination_root)
    end

    def create_app_directories
      empty_directory 'app/controllers'
      empty_directory 'app/models'
      empty_directory 'app/replicators'

      empty_directory 'config'
      empty_directory 'db/migrations'
      empty_directory 'lib'
      empty_directory 'log'
      empty_directory 'spec'
    end

    def generate_files
      template('Gemfile.tt', 'Gemfile')
      template('service.tt', "#{app_name}.rb")
      template('boot.tt', 'boot.rb')
      template('config/version.tt', 'config/version.rb')
      template('config/config.tt', 'config/config.rb')
    end

    def install_gems
      inside app_name do
        run 'bundle install'
      end
    end
  end
end
