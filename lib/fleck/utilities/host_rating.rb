# frozen_string_literal: true

require 'socket'

# Open `Fleck` module to add `HostRating` class.
module Fleck
  # `HostRating` class allows to test host latency on a regular basis and to compare the latency
  # with other hosts.
  class HostRating
    include Fleck::Loggable

    CONN_TIMEOUT = 5

    attr_reader :host, :port, :avg, :history

    def initialize(host: 'localhost', port: 5672, refresh_rate: 30_000, period: 300_000)
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
      @timer = Ztimer.every(@refresh_rate) { refresh! }
    end

    def reachable?
      @reachable
    end

    def close
      @timer.cancel!
    end

    def <=>(other)
      # the other host is reachable, so it comes first
      return 1 if !reachable? && other.reachable?

      # both host are unreachable, so they have the same priority
      return 0 unless reachable? || other.reachable?

      # the current host comes first, because it's reachable, while the other host is unreachable
      return -1 if reachable? && !other.reachable?

      # when both hosts are reachable, use avg latency to order them
      avg <=> other.avg
    end

    private

    def refresh!
      @history << measure_latency
      @history.shift if @history.size > @period / @refresh_rate
      @avg = @history.inject(:+).to_f / @history.size
      @reachable = true
    rescue SocketError, Timeout::Error => e
      @reachable = false
      logger.error "Connection error: #{@host}:#{@port} (#{e.inspect})"
    ensure
      @updated_at = Time.now
    end
  end

  private

  # Use a socket to test connection latency.
  def measure_latency
    socket = create_socket

    started_at = Time.now.to_f
    begin
      socket.connect_nonblock(sock_addr)
    rescue IO::WaitWritable
      IO.select(nil, [socket], nil, CONN_TIMEOUT) or raise Timeout::Error
    end

    (Time.now.to_f - started_at) * 1000 # ms
  ensure
    socket&.close
  end

  # Create a new socket for connection test.
  def create_socket
    socket = Socket.new(:AF_INET, :SOCK_STREAM, 0)
    socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

    socket
  end

  # Resolve domain name in order to obtain IP address to test.
  def sock_addr
    return @sock_addr if @sock_addr

    addr = Socket.getaddrinfo(@host, nil)
    @sock_addr = Socket.pack_sockaddr_in(@port, addr[0][3])

    @sock_addr
  end
end
