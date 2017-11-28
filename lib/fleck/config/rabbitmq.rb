
module Fleck
  class Config::Rabbitmq
    PERMITED_PARAMS = ["cluster", "name"]

    attr_accessor :clusters, :hosts, :queues
    def initialize(rmq_configs = {}, queues_configs = {})
      @configs  = rmq_configs || {}
      @queues_configs = queues_configs || {}
      @last_idx = 0
      @clusters = {}
      @hosts    = []
      @queues   = {}

      load_clusters!
      load_hosts!
      load_queues!
    end

    def new_connection(cluster: nil)
      selected_cluster = cluster ? @clusters[cluster.to_s] : @clusters.values.first

      start_connection(selected_cluster || [])
    end


    def queue_exists?(queue_name)
      return !@queues[queue_name].nil?
    end

    private

    #####################################################################################################
    # Load the list of RabbitMQ clusters.
    #
    # Every RabbitMQ host configuration belongs to a cluster.
    #####################################################################################################
    def load_clusters!
      if @configs["clusters"]
        clusters = @configs["clusters"]
        if clusters.is_a?(Array)
          # The list of clusters is expressed as an Array of strings
          @clusters = Hash[clusters.map{|name| [name.to_s, []] }]
        elsif clusters.is_a?(String)
          # The list of clusters is expressed as a single String, where each name is separated by a comma
          clusters = clusters.split(",").map{|item| item.strip }.reject{|item| item == "" }
          @clusters = Hash[clusters.map{|name| [name, []] }] unless clusters.empty?
        else
          # Cluster config has an invalid value type
          raise "Invalid value for @config.rabbitmq.clusters = #{clusters.inspect}"
        end
      end

      # Load clusters' names from RMQ_CLUSTERS environment variable, if set
      if ENV["RMQ_CLUSTERS"].to_s.strip != ""
        clusters = ENV["RMQ_CLUSTERS"].split(",").map{|item| item.strip }.reject{|item| item == "" }
        @clusters = Hash[clusters.map{|name| [name, []] }] unless clusters.empty?
      end

      # If clusters list is still empty, add "default" cluster
      @clusters["default"] = [] if @clusters.empty?
    end


    #####################################################################################################
    # Load the list of RabbitMQ hosts
    #
    # Example 1:
    # -------------------
    # rabbitmq:
    #   hosts:
    #     rabbitmq_1:
    #       cluster: default
    #       host: 10.0.0.1
    #       port: 5672
    #       user: bunny
    #       pass: secret
    #       vhost: /
    #     rabbitmq_2: ampq://user:secret@10.0.0.2:5673/myvhost?cluster=default
    #     ...
    # -------------------
    #
    # Example 2:
    # -------------------
    # rabbitmq:
    #   hosts:
    #     - ampq://bunny:secret@10.0.0.1:5672?name=rabbitmq1&cluster=default
    #     ...
    # -------------------
    #
    # Example 3:
    # -------------------
    # rabbitmq:
    #   hosts: ampq://127.0.0.1:5672, ampq://bunny:secret@10.0.0.1:5672
    # -------------------
    #####################################################################################################
    def load_hosts!

      if @configs["hosts"]
        hosts = @configs["hosts"]
        if hosts.is_a?(Hash)
          # Case 1
          @hosts = hosts.map do |name, host|
            if host.is_a?(Hash)
              check_host_config(host.merge({"name": name}))
            elsif host.is_a?(String)
              parse_host_uri(host, name)
            else
              raise "Unsupported config type for @config.rabbitmq.hosts item: #{name}: #{host.inspect}"
            end
          end

        elsif hosts.is_a?(Array)
          # Case 2
          @hosts = hosts.map do |rmq_uri|
            if rmq_uri.is_a?(String)
              parse_host_uri(rmq_uri)
            else
              raise "Unsupported config type for @config.rabbitmq.hosts item: #{rmq_uri.inspect}"
            end
          end

        elsif hosts.is_a?(String)
          # Case 3
          hosts = hosts.split(",").map{|item| item.strip }.reject{|item| item == "" }
          unless hosts.empty?
            @hosts = hosts.map{|rmq_uri| parse_host_uri(rmq_uri)}
          end

        else
          raise "Unsupported config type for @config.rabbitmq.hosts: #{hosts.inspect}"
        end
      end

      if ENV["RMQ_HOSTS"].to_s.strip != ""
        hosts = ENV["RMQ_HOSTS"].split(",").map{|item| item.strip }.reject{|item| item == "" }
        @hosts = hosts.map{|rmq_uri| parse_host_uri(rmq_uri) } unless hosts.empty?
      end

      @hosts = [check_host_config({})] if @hosts.empty?
      @hosts.each do |host|
        @clusters[host["cluster"]] << host
      end
    end


    #####################################################################################################
    # Load RabbitMQ queues configurations
    #####################################################################################################
    def load_queues!
      defaults = @queues_configs.select{|k,_| ["exchange_type", "exchange_name", "cluster", "threads"].include?(k) }

      queues = @queues_configs.reject{|k,_| ["exchange_type", "exchange_name", "cluster", "threads"].include?(k) }
      queues.each do |label, value|
        if value.is_a?(String)
          @queues[label] = defaults.dup
          @queues[label]["name"] = value
          check_queue_configs(@queues[label], defaults)
        elsif value.is_a?(Hash)
          @queues[label] = defaults.dup
          @queues[label].merge!(value)
          check_queue_configs(@queues[label], defaults)
        else
          raise "Unsupported queue config type: (#{value.class.name}) #{value.inspect}"
        end
      end
    end


    #####################################################################################################
    # Extract host configs from a URI string
    #####################################################################################################
    def parse_host_uri(rmq_uri, name = nil)
      uri = URI.parse(rmq_uri.start_with?("ampq") ? rmq_uri : "ampq://#{rmq_uri}")
      params = URI.decode_www_form(uri.query.to_s).to_h
      vhost = (uri.path.strip == "" ? "/" : uri.path)
      tls = (uri.scheme.downcase == "ampqs")

      # Set params defaults and filter unsupported params
      params["name"] ||= name
      params = params.select{|k,v| PERMITED_PARAMS.include?(k)}

      params.merge!({
        "host"    => uri.host,
        "port"    => uri.port,
        "user"    => uri.user,
        "pass"    => uri.password,
        "vhost"   => vhost,
        "tls"     => tls
      })

      return check_host_config(params)
    end


    #####################################################################################################
    # Check if host's config is OK and set default values where missing
    #####################################################################################################
    def check_host_config(cfg)
      cfg["name"]    ||= generate_host_name
      cfg["cluster"] ||= @clusters.keys.first
      cfg["host"]    ||= "127.0.0.1"
      cfg["port"]    ||= 5672
      cfg["user"]    ||= "guest"
      cfg["pass"]    ||= "guest"
      cfg["vhost"]   ||= "/"
      cfg["tls"]     ||= false

      if @clusters[cfg["cluster"]].nil?
        raise "Invalid cluster name #{cfg['cluster'].inspect} for RabbitMQ host: #{cfg.inspect}"
      end

      check_type_of cfg["name"],    name: "rabbitmq.host.name",    expected: String
      check_type_of cfg["cluster"], name: "rabbitmq.host.cluster", expected: String
      check_type_of cfg["host"],    name: "rabbitmq.host.host",    expected: String
      check_type_of cfg["port"],    name: "rabbitmq.host.port",    expected: Fixnum
      check_type_of cfg["user"],    name: "rabbitmq.host.user",    expected: String
      check_type_of cfg["pass"],    name: "rabbitmq.host.pass",    expected: String
      check_type_of cfg["vhost"],   name: "rabbitmq.host.vhost",   expected: String
      check_type_of cfg["tls"],     name: "rabbitmq.host.tls",     expected: [TrueClass, FalseClass]

      return cfg
    end


    #####################################################################################################
    # Check queue configs and set defaults when config is missing
    #####################################################################################################
    def check_queue_configs(cfg, defaults = {})
      cfg["exchange_type"] ||= defaults["exchange_type"] || "direct"
      cfg["exchange_name"] ||= defaults["exchange_name"] || ""
      cfg["cluster"]       ||= defaults["cluster"] || @clusters.keys.first
      cfg["threads"]       ||= defaults["threads"] || 1

      check_type_of cfg["name"],          name: "rabbitmq.queue.name",          expected: String
      check_type_of cfg["exchange_type"], name: "rabbitmq.queue.exchange_type", expected: String
      check_type_of cfg["exchange_name"], name: "rabbitmq.queue.exchange_name", expected: String
      check_type_of cfg["cluster"],       name: "rabbitmq.queue.cluster",       expected: String
      check_type_of cfg["threads"],       name: "rabbitmq.queue.threads",       expected: Fixnum

      if @clusters[cfg["cluster"]].nil?
        raise "Invalid cluster name #{cfg['cluster'].inspect} for RabbitMQ queue #{cfg['name'].inspect}"
      end

      unless ["direct", "topic", "fanout", "headers"].include?(cfg["exchange_type"])
        raise "Invalid exchange_type #{cfg["exchange_type"].inspect} for queue #{cfg['name'].inspect}"
      end

      if cfg["consumption_mode"].nil?
        if cfg["exchange_type"] == "direct"
          cfg["consumption_mode"] = "round-robin"
        else
          cfg["consumption_mode"] = "broadcast"
        end
      end

      unless ["round-robin", "broadcast"].include?(cfg["consumption_mode"])
        raise "Invalid consumption_mode #{cfg["consumption_mode"].inspect} for queue #{cfg['name'].inspect}"
      end

      return cfg
    end


    #####################################################################################################
    # Generate a new name for RabbitMQ host configuration
    #####################################################################################################
    def generate_host_name
      @last_idx += 1
      return "rabbitmq_#{@last_idx}"
    end


    #####################################################################################################
    # Validate the type of a value
    #####################################################################################################
    def check_type_of(value, name: "config", expected: Nil)
      if (expected.is_a?(Array) && expected.include?(value.class)) || (expected.is_a?(Class) && value.is_a?(expected))
        value
      else
        raise "Invalid type for ##{name} = #{value.inspect}: #{expected} expected"
      end
    end


    #####################################################################################################
    # Start a new RabbitMQ connection
    #####################################################################################################
    def start_connection(hosts = [])
      condition = Lounger.new
      workers   = Ztimer.new(concurrency: hosts.count)
      count     = 0
      result    = nil

      hosts.each do |configs|
        opts = configs.dup
        workers.async do
          begin
            conn = Bunny.new(opts)
            condition.signal conn
          rescue => e
            puts e.to_s + "\n" + e.backtrace.join("\n")
            condition.signal nil
          end
        end
      end

      while result.nil? && count < hosts.count do
        result = condition.wait
        count += 1
      end

      Thread.new do
        [hosts.count - count].times do
          conn = condition.wait
          conn.close if conn && conn.respond_to?(close)
        end
      end

      fail "Failed to start a new RabbitMQ connection!" if result.nil?

      return result
    end
  end
end