# frozen_string_literal: true

# Open `Fleck` module to define `ConsumerBase` class.
module Fleck::Core
  class ConsumerBase
    class << self
      attr_accessor :logger, :configs, :actions_map, :consumers, :initialize_block

      def inherited(subclass)
        super
        init_consumer(subclass)
        autostart(subclass)
        Fleck.register_consumer(subclass)
      end

      def configure(opts = {})
        configs.merge!(opts)
        logger.debug 'Consumer configurations updated.'
      end

      def actions(*args)
        args.each do |item|
          case item
          when Hash then item.each { |k, v| register_action(k.to_s, v.to_s) }
          else register_action(item.to_s, item.to_s)
          end
        end
      end

      def register_action(action, method_name)
        if Fleck::Consumer.instance_methods.include?(method_name.to_s.to_sym)
          raise ArgumentError, "Cannot use `:#{method_name}` method as an action, " \
                                'because it is reserved for Fleck::Consumer internal stuff!'
        end

        actions_map[action.to_s] = method_name.to_s
      end

      def initialize(&block)
        self.initialize_block = block
      end

      def start(block: false)
        consumers.each do |consumer|
          consumer.start(block: block)
        end
      end

      def error_method(name, code, message)
        define_method(name) do |details|
          response.render_error(code, message + [details].flatten)
        end
      end

      def redirect_method(name, code)
        success_method(name, code)
      end

      def success_method(name, code)
        define_method(name) do |body|
          response.status = code
          response.body = body
        end
      end

      def information_method(name, code)
        success_method(name, code)
      end

      def init_consumer(subclass)
        subclass.logger          = Fleck.logger.clone
        subclass.logger.progname = subclass.to_s

        subclass.logger.debug "Setting defaults for #{subclass.to_s.color(:yellow)} consumer"

        subclass.configs = Fleck.config.default_options
        subclass.configs[:autostart] = true if subclass.configs[:autostart].nil?
        subclass.actions_map = {}
        subclass.consumers   = []
      end

      def autostart(subclass)
        # Use TracePoint to autostart the consumer when ready
        trace = TracePoint.new(:end) do |tp|
          if tp.self == subclass
            # disable tracing when we reach the end of the subclass
            trace.disable
            # create a new instance of the subclass, in order to start the consumer
            [subclass.configs[:concurrency].to_i, 1].max.times do |i|
              subclass.consumers << subclass.new(i)
            end
          end
        end
        trace.enable
      end

      # TODO: implement the feature for action decorators
      def method_added(name)
        reset_method_options!
      end

      def method_options
        @method_options ||= default_method_options
      end

      def default_method_options
        {
          params: {}.to_hash_with_indifferent_access,
          headers: {}.to_hash_with_indifferent_access,
          description: nil
        }
      end

      def reset_method_options!
        @method_options = nil
      end

      def desc(description)
        method_options[:description] = description
      end

      def param(name, options = {})
        method_options[:params][name] = options
      end

      def header(name, options = {})
        method_options[:headers][name] = options
      end
    end

    def initialize(thread_id = nil)
      @__thread_id = thread_id
      @__connection   = nil
      @__consumer_tag = nil
      @__request      = nil
      @__response     = nil
      @__lock         = Mutex.new
      @__lounger      = ConditionVariable.new
    end
  end
end
