# frozen_string_literal: true

$LOAD_PATH << File.expand_path(__dir__)

module Fleck
  class Application
    # A class to define application configurations.
    class Configuration
      attr_accessor :env

      APP_BOOT_FILE = 'boot.rb'

      def initialize
        @args = ARGV.dup
        @env = ENV['FLECK_ENV'] || ENV['RACK_ENV'] || 'development'
        @root = find_root

        puts "Args: #{@args.inspect}"

        puts 'Created new Fleck configuration'
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
end
