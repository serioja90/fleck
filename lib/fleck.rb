require "logger"
require "rainbow"
require "rainbow/ext/string"
require "bunny"
require "thread_safe"
require "fleck/version"
require "fleck/configuration"
require "fleck/consumer"

module Fleck
  @config      = Configuration.new
  @consumers   = ThreadSafe::Array.new
  @connections = ThreadSafe::Hash.new

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
    opts = options
    key  = "ampq://#{opts[:user]}@#{opts[:host]}:#{opts[:port]}#{opts[:vhost]}"
    conn = @connections[key]
    if !conn || conn.closed?
      logger.info "New connection #{key}"
      conn = Bunny.new(opts)
      conn.start
      @connections[key] = conn
    end
    return conn
  end

  private

  class << self
    attr_reader :config
  end

end
