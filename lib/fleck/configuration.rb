
module Fleck
  class Configuration

    attr_reader :logfile, :loglevel, :progname
    attr_accessor :default_user, :default_pass, :default_host, :default_port, :default_vhost, :default_queue, :app_name,
                  :tls, :tls_ca_certs, :tls_cert, :tls_key, :verify_peer

    def initialize
      @logfile              = STDOUT
      @loglevel             = ::Logger::INFO
      @progname             = "Fleck"
      @app_name             = $0
      @default_host         = "127.0.0.1"
      @default_port         = 5672
      @default_user         = nil
      @default_pass         = nil
      @default_vhost        = "/"
      @default_queue        = "default"

      @tls          = false
      @tls_ca_certs = ["#{ENV['HOME']}/.rabbitmq/cacert.pem"]
      @tls_cert     = "#{ENV['HOME']}/.rabbitmq/cert.pem"
      @tls_key      = "#{ENV['HOME']}/.rabbitmq/key.pem"
      @verify_peer  = true
    end

    def default_options
      opts                       = {}
      opts[:host]                = @default_host
      opts[:port]                = @default_port
      opts[:user]                = @default_user
      opts[:pass]                = @default_pass
      opts[:vhost]               = @default_vhost
      opts[:queue]               = @default_queue

      # SSL/TLS configurations
      opts[:tls]                 = @tls
      opts[:tls_ca_certificates] = @tls_ca_certs
      opts[:tls_cert]            = @tls_cert
      opts[:tls_key]             = @tls_key
      opts[:verify_peer]         = @verify_peer

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