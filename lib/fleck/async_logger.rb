require 'logger'
require 'timeout'

module Fleck
  class AsyncLogger < Logger

    attr_accessor :exit_timeout

    def initialize(*args)
      super(*args)

      @queue = Queue.new

      @thread = Thread.new do
        loop do
          begin
            @queue.pop.call
          rescue IOError
          end
        end
      end

      trap "INT" do
        # On Ctrl-C try to close the logger and set a timeout of 3 seconds
        begin
          Timeout::timeout(3) do
            close
          end
        rescue Timeout::Error
          # The logger wasn't closed in 3 seconds. Terminate the thread and
          # clear the queue
          @thread.exit
          @queue.clear
        end
      end

      at_exit do
        close
        exit
      end
    end

    def close
      while !@queue.empty? do
        sleep 0.05
      end
      @thread.exit
      @queue.clear
      super
    end

    def debug(progname = nil, &block)
      async { super(progname, &block) }
    end

    def info(progname = nil, &block)
      async { super(progname, &block) }
    end

    def warn(progname = nil, &block)
      async { super(progname, &block) }
    end

    def error(progname = nil, &block)
      async { super(progname, &block) }
    end

    def fatal(progname = nil, &block)
      async { super(progname, &block) }
    end

    def <<(message)
      async { super(message) }
    end

    def add(severity, message = nil, progname = nil, &block)
      async { super(severity, message, progname, &block) }
    end

    def namespaced_logger(progname)
      NamespacedLogger.new(progname, self)
    end

    private

    def async(&block)
      @queue.push block
      return true
    end
  end
end