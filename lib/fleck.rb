require "logger"
require "rainbow"
require "rainbow/ext/string"
require "bunny"
require "thread_safe"
require "securerandom"
require "oj"
require "fleck/version"
require "fleck/hash_with_indifferent_access"
require "fleck/configuration"
require "fleck/loggable"
require "fleck/consumer"
require "fleck/client"

module Fleck
  @config      = Configuration.new
  @consumers   = ThreadSafe::Array.new
  @connections = ThreadSafe::Hash.new

  at_exit do
    Fleck.terminate
  end

  def self.configure
    yield @config if block_given?
    @config
  end

  def self.logger
    @config.logger
  end

  def self.register_consumer(consumer_class)
    unless @consumers.include?(consumer_class)
      @consumers << consumer_class
    end
  end

  def self.connection(options)
    opts = Fleck.config.default_options.merge(options)
    key  = "ampq://#{opts[:user]}@#{opts[:host]}:#{opts[:port]}#{opts[:vhost]}"
    conn = @connections[key]
    if !conn || conn.closed?
      opts[:logger] = Fleck.logger.clone
      opts[:logger].progname += "::Bunny"
      logger.info "New connection #{key}"
      conn = Bunny.new(opts)
      conn.start
      @connections[key] = conn
    end
    return conn
  end

  def self.terminate
    @connections.each do |key, connection|
      begin
        Fleck.logger.info "Closing connection #{key}"
        connection.close
      rescue => e
        Fleck.logger.error e.inspect
      end
    end
    @connections.clear

    true
  end

  private

  class << self
    attr_reader :config
  end

end
