
module Fleck::Loggable
  def logger
    return @logger if @logger

    @logger = Fleck.logger.clone
    @logger.progname = self.class.name

    @logger
  end
end
