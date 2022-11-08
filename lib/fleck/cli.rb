# frozen_string_literal: true

$LOAD_PATH << File.expand_path(__dir__)

require 'thor'

module Fleck
  autoload :NewApp, 'cli/commands/new.rb'

  # Fleck CLI implements a Command Line Interface for easier Fleck app creation and configuration.
  class CLI < Thor
    desc 'new APP_NAME', 'Generate a new Fleck application'
    method_option 'no-db', type: :boolean, default: false, desc: 'Do not generate database configuration'
    method_option 'no-kafka', type: :boolean, default: false, desc: 'Do not generate Kafka configuration'
    def new_app(app_name)
      NewApp.new(app_name, options)
    end

    desc 'start', 'Start the Fleck application'
    def start(*args)
      # TODO: this method could be used to load and run the Fleck app.
      # We can use optionparser to parse the arguments and configure the app accordingly, like
      # in the example below.
      # Also, we should consider env variables to configure the application before processing the arguments.
      puts args.inspect

      # TODO: configure the app with env variables.
      # TODO: parse the arguments and configure the app accordingly.

      require 'optparse'

      # Parse command-line options
      options = OptionParser.new do |opts|
        opts.on('-n', '--name NAME', 'Name of the consumer') do |name|
          puts "Name: #{name}"
        end
      end

      options.parse!(args)
    end
  end
end
