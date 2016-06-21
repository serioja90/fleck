require 'socket'

module Fleck
  class HostRating
    include Fleck::Loggable

    CONN_TIMEOUT = 5

    attr_reader :host, :port, :avg, :history

    def initialize(host: 'localhost', port: 5672, refresh_rate: 30000, period: 300000)
      @host         = host
      @port         = port
      @refresh_rate = refresh_rate
      @period       = period

      # metrics
      @reachable  = false
      @avg        = 0
      @updated_at = nil
      @history    = []

      refresh!
      @timer = Ztimer.every(@refresh_rate){ refresh! }
    end

    def reachable?
      @reachable
    end

    def close
      @timer.cancel!
    end

    def <=>(other_host)
      return 1 if !self.reachable? && other_host.reachable? # the other host is reachable, so it comes first
      return 0  if !(self.reachable? || other_host.reachable?) # both host are unreachable, so they have the same priority
      return -1  if self.reachable? && !other_host.reachable? # the current host comes first, because it's reachable, while the other host is unreachable

      # when both hosts are reachable, use avg latency to order them
      return self.avg <=> other_host.avg
    end

    private

    def refresh!
      # Get host info and open a new socket
      addr = Socket.getaddrinfo(@host, nil)
      sock_addr = Socket.pack_sockaddr_in(@port, addr[0][3])
      socket = Socket.new(:AF_INET, :SOCK_STREAM, 0)
      socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

      started_at = Time.now.to_f
      begin
        socket.connect_nonblock(sock_addr)
      rescue IO::WaitWritable
        IO.select(nil, [socket], nil, CONN_TIMEOUT) or raise Timeout::Error
      end
      latency = (Time.now.to_f - started_at) * 1000 # ms
      socket.close

      @history << latency
      @history.shift if @history.size > @period / @refresh_rate
      @avg = @history.inject(:+).to_f / @history.size
      @reachable = true
    rescue SocketError, Timeout::Error => e
      socket.close if socket
      @reachable = false
      logger.error "Connection error: #{@host}:#{@port} (#{e.inspect})"
    ensure
      @updated_at = Time.now
    end
  end
end