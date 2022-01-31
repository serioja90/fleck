# frozen_string_literal: true

# Open `Fleck` module to add `Configuration` class implementation.
module Fleck
  # `Fleck::Configuration` implements a set of methods useful for `Fleck` clients and consumers configuration.
  class Configuration
    autoload :HostRating, 'fleck/utilities/host_rating.rb'

    attr_reader :logfile, :loglevel, :progname, :hosts
    attr_accessor :default_user, :default_pass, :default_host, :default_port, :default_vhost, :default_queue,
                  :app_name, :filters

    def initialize
      @logfile       = $stdout
      @loglevel      = ::Logger::INFO
      @progname      = 'Fleck'
      @app_name      = $PROGRAM_NAME
      @default_host  = '127.0.0.1'
      @default_port  = 5672
      @default_user  = nil
      @default_pass  = nil
      @default_vhost = '/'
      @default_queue = 'default'
      @filters       = %w[password secret token]
      @hosts         = []
      @credentials   = {}
    end

    def hosts=(*args)
      args.flatten.each do |host|
        add_host host
      end
    end

    def add_host(data)
      case data
      when String then add_host_from_string(data)
      when Hash then add_host_from_hash(data)
      else
        raise ArgumentError, "Invalid host type #{data.inspect}: String or Hash expected"
      end
    end

    def default_options
      best = @hosts.min
      opts = {}

      host = best ? best.host : @default_host
      port = best ? best.port : @default_port
      credentials = @credentials["#{host}:#{port}"] || { user: @default_user, pass: @default_pass }

      opts[:host]  = host
      opts[:port]  = port
      opts[:user]  = credentials[:user] || @default_user
      opts[:pass]  = credentials[:pass] || @default_pass
      opts[:vhost] = @default_vhost
      opts[:queue] = @default_queue

      opts
    end

    def logfile=(new_logfile)
      return unless @logfile != new_logfile

      @logfile = new_logfile
      reset_logger
    end

    def loglevel=(new_loglevel)
      @loglevel = new_loglevel
      @logger.level = @loglevel if @logger
    end

    def progname=(new_progname)
      @progname = new_progname
      @logger.progname = @progname if @logger
    end

    def logger
      @logger || reset_logger
    end

    def logger=(new_logger)
      @logger&.close

      if new_logger.nil?
        @logger = ::Logger.new(nil)
      else
        @logger = new_logger.clone
        @logger.formatter = formatter
        @logger.progname  = @progname
        @logger.level     = @loglevel
      end
    end

    def reset_logger
      new_logger = ::Logger.new(@logfile)
      new_logger.formatter = formatter
      new_logger.progname  = @progname
      new_logger.level     = @loglevel
      @logger&.close
      @logger = new_logger

      @logger
    end

    def formatter
      return @formatter if @formatter

      @formatter = proc do |severity, datetime, progname, msg|
        color = severity_color(severity)
        "[#{datetime.strftime('%F %T.%L')}]".color(:cyan) +
          "(#{$PID})".color(:blue) +
          "|#{severity}|".color(color) +
          (progname ? "<#{progname}>".color(:yellow) : '') +
          " #{msg}\n"
      end

      @formatter
    end

    private

    def add_host_from_string(data)
      host, port = data.split(':')
      port = port ? port.to_i : 5672
      @hosts << Fleck::HostRating.new(host: host, port: port)
      @credentials["#{host}:#{port}"] ||= { user: @default_user, pass: @default_pass }
    end

    def add_host_from_hash(data)
      data = data.to_hash_with_indifferent_access
      host = data[:host] || @default_host
      port = data[:port] || @default_port
      @hosts << Fleck::HostRating.new(host: host, port: port)
      @credentials["#{host}:#{port}"] ||= { user: data[:user] || @default_user, pass: data[:pass] || @default_pass }
    end

    def severity_color(severity)
      case severity
      when 'DEBUG' then '#512DA8'
      when 'INFO' then '#33691E'
      when 'WARN' then '#E65100'
      when 'ERROR', 'FATAL' then '#B71C1C'
      else '#00BCD4'
      end
    end
  end
end
