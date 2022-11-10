# frozen_string_literal: true

$LOAD_PATH << File.expand_path(__dir__)

# Fleck module, which is a namespace for all Fleck classes and modules.
# Use `Fleck.application` to access the current application
module Fleck
  class << self
    def application
      @application ||= Application.new
    end
  end

  # A class that represents a Fleck application and provides all the features for applucation
  # configuration and running.
  class Application
    autoload :Configuration, 'application/configuration.rb'

    attr_reader :config

    def initialize
      @config = Configuration.new
    end

    def run!
      puts 'Running Fleck application'
    end

    def configure
      yield @config if block_given?
    end

    def env
      @config.env
    end
  end
end
