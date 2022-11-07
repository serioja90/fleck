# frozen_string_literal: true

require 'thor'

module Fleck
  # Fleck CLI implements a Command Line Interface for easier Fleck app creation and configuration.
  class CLI < Thor
    desc 'new APP_NAME', 'Generate a new Fleck application'
    method_option 'no-db', type: :boolean, default: false, desc: 'Do not generate database configuration'
    method_option 'no-kafka', type: :boolean, default: false, desc: 'Do not generate Kafka configuration'
    def new_app(app_name)
      require_relative 'cli/new_app'
      Fleck::NewApp.new(app_name, options)
    end
  end
end
