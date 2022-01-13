
module Fleck::Loggable
  def logger
    return @logger if @logger

    @logger = Fleck.logger.clone
    @logger.progname = self.class.name

    @logger
  end

  def log_error(error)
    logger.error "#{error.inspect}\n#{error.backtrace.join("\n")}"
  end
end
