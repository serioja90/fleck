# frozen_string_literal: true

$LOAD_PATH << File.expand_path(__dir__)

require 'English'
require 'logger'
require 'rainbow'
require 'rainbow/ext/string'
require 'bunny'
require 'thread_safe'
require 'securerandom'
require 'oj'
require 'ztimer'
# require 'fleck/version'
require 'fleck/utilities/hash_with_indifferent_access'
# require 'fleck/loggable'
# require 'fleck/host_rating'
# require 'fleck/configuration'
# require 'fleck/consumer'
# require 'fleck/client'

# `Fleck` module implements the features for `Fleck` configuration and messages production/consumption.
module Fleck
  autoload :VERSION, 'fleck/version.rb'
  autoload :Loggable, 'fleck/loggable.rb'
  autoload :HostRating, 'fleck/utilities/host_rating.rb'
  autoload :Configuration, 'fleck/configuration.rb'
  autoload :Core, 'fleck/core.rb'
  autoload :Consumer, 'fleck/consumer.rb'
  autoload :Client, 'fleck/client.rb'

  @config      = Configuration.new
  @consumers   = ThreadSafe::Array.new
  @connections = ThreadSafe::Hash.new

  class << self
    attr_reader :config, :consumers

    def configure
      yield @config if block_given?
      @config
    end

    def logger
      @config.logger
    end

    def register_consumer(consumer_class)
      return if @consumers.include?(consumer_class)

      @consumers << consumer_class
    end

    def connection(options = {})
      opts = Fleck.config.default_options.merge(options)
      key  = "ampq://#{opts[:user]}@#{opts[:host]}:#{opts[:port]}#{opts[:vhost]}"
      conn = @connections[key]
      if !conn || conn.closed?
        opts[:logger] = Fleck.logger.clone
        opts[:logger].progname += '::Bunny'
        logger.info "New connection #{key}"
        conn = Bunny.new(opts)
        conn.start
        @connections[key] = conn
      end

      conn
    end

    def terminate
      @connections.each do |key, connection|
        Fleck.logger.info "Closing connection #{key}"
        connection.close
      rescue StandardError => e
        Fleck.logger.error e.inspect
      end
      @connections.clear

      true
    end
  end
end
