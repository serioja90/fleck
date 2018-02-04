
module Fleck
  class NamespacedLogger

    attr_accessor :progname

    def initialize(progname, logger)
      @progname = progname
      @logger   = logger
    end

    def debug(message)
      @logger.debug(@progname){ message }
    end

    def info(message)
      @logger.info(@progname){ message }
    end

    def warn(message)
      @logger.warn(@progname){ message }
    end

    def error(message)
      @logger.error(@progname){ message }
    end

    def fatal(message)
      @logger.fatal(@progname){ message }
    end

    def <<(message)
      @logger << message
    end

    def add(severity, message = nil, &block)
      @logger.add(severity, message, @progname, &block)
    end

    def method_missing(method_missing, *args, &block)
      @logger.send(method_missing, *args, &block)
    end
  end
end