require "logger"
require "rainbow"
require "rainbow/ext/string"
require "bunny"
require "celluloid"
require "fleck/version"
require "fleck/configuration"
require "fleck/consumer"

module Fleck
  @started    = false
  @config     = Configuration.new
  @connection = nil
  @channel    = nil
  @consumers  = []

  def self.configure
    yield @config if block_given?
    @config
  end

  def self.logger
    @config.logger
  end

  def self.register_consumer(consumer)
    unless @consumers.include?(consumer.class)
      @consumers << consumer.class
      consumer.class.new
    end
  end

  def self.start
    if @started
      logger.warn "Fleck service already running."
    else
      logger.info "Connecting to #{@config.host}:#{@config.port} as #{@config.username || 'guest'}"
      @connection = Bunny.new(@config.auth_options)
      @connection.start

      logger.info "Creating a new channel..."
      @channel = connection.create_channel
      @started = true
      logger.info "Fleck service successfully started!"
    end
  end

  def self.started?
    @started
  end

  private

  class << self
    attr_reader :config
  end

end
