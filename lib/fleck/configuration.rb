
module Fleck
  class Configuration

    attr_reader :logfile, :loglevel, :progname, :hosts
    attr_accessor :default_user, :default_pass, :default_host, :default_port, :default_vhost, :default_queue,
                  :app_name, :filters

    def initialize
      @logfile       = STDOUT
      @loglevel      = ::Logger::INFO
      @progname      = "Fleck"
      @app_name      = $0
      @default_host  = "127.0.0.1"
      @default_port  = 5672
      @default_user  = nil
      @default_pass  = nil
      @default_vhost = "/"
      @default_queue = "default"
      @filters       = ["password", "secret", "token"]
      @hosts         = []
      @credentials   = {}
    end

    def hosts=(*args)
      args.flatten.each do |host|
        add_host host
      end
      return @hosts
    end

    def add_host(data)
      if data.is_a?(String)
        host, port = data.split(":")
        port = port ? port.to_i : 5672
        @hosts << Fleck::HostRating.new(host: host, port: port)
        @credentials["#{host}:#{port}"] ||= { user: @default_user, pass: @default_pass }
      elsif data.is_a?(Hash)
        data = data.to_hash_with_indifferent_access
        host = data[:host] || @default_host
        port = data[:port] || @default_port
        @hosts << Fleck::HostRating.new(host: data[:host] || @default_host, port: data[:port] || @default_port)
        @credentials["#{host}:#{port}"] ||= { user: data[:user] || @default_user, pass: data[:pass] || @default_pass }
      else
        raise ArgumentError.new("Invalid host type #{data.inspect}: String or Hash expected")
      end
    end

    def default_options
      best = @hosts.sort.first
      opts = {}

      host = best ? best.host : @default_host
      port = best ? best.port : @default_port
      credentials = @credentials["#{host}:#{port}"] || {user: @default_user, pass: @default_pass}

      opts[:host]  = host
      opts[:port]  = port
      opts[:user]  = credentials[:user] || @default_user
      opts[:pass]  = credentials[:pass] || @default_pass
      opts[:vhost] = @default_vhost
      opts[:queue] = @default_queue

      return opts
    end

    def logfile=(new_logfile)
      if @logfile != new_logfile
        @logfile = new_logfile
        reset_logger
      end

      return @logfile
    end

    def loglevel=(new_loglevel)
      @loglevel = new_loglevel
      @logger.level = @loglevel if @logger

      return @loglevel
    end

    def progname=(new_progname)
      @progname = new_progname
      @logger.progname = @progname if @logger

      return @progname
    end

    def logger
      return @logger || reset_logger
    end

    def logger=(new_logger)
      if new_logger.nil?
        @logger.close if @logger
        @logger = ::Logger.new(nil)
      else
        @logger.close if @logger
        @logger = new_logger.clone
        @logger.formatter = formatter
        @logger.progname  = @progname
        @logger.level     = @loglevel
      end

      return @logger
    end

    def reset_logger
      new_logger = ::Logger.new(@logfile)
      new_logger.formatter = formatter
      new_logger.progname  = @progname
      new_logger.level     = @loglevel
      @logger.close if @logger
      @logger = new_logger

      return @logger
    end

    def formatter
      return @formatter if @formatter

      @formatter = proc do |severity, datetime, progname, msg|
        color = :blue
        case severity
        when 'DEBUG'
          color = "#512DA8"
        when 'INFO'
          color = "#33691E"
        when 'WARN'
          color = "#E65100"
        when 'ERROR', 'FATAL'
          color = "#B71C1C"
        else
          color = "#00BCD4"
        end
        "[#{datetime.strftime('%F %T.%L')}]".color(:cyan) + "(#{$$})".color(:blue) + "|#{severity}|".color(color) +
        (progname ? "<#{progname}>".color(:yellow) : "")  + " #{msg}\n"
      end

      return @formatter
    end
  end
end