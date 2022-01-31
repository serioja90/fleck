# frozen_string_literal: true

module Fleck
  module Core
    class Consumer
      # Stores data about an action parameter, which will be used for automatic parameters validation.
      class ActionParam
        AVAILABLE_TYPES = %w[string number boolean object array].freeze
        TYPE_ALIASES = {
          'text' => 'string',
          'integer' => 'number',
          'float' => 'number',
          'hash' => 'object'
        }.freeze

        attr_reader :name, :type, :options

        def initialize(name, type, options = {})
          @name = name
          @type = type
          @options = options

          check_options!
        end

        def string?
          @type == 'string'
        end

        def required?
          options[:required]
        end

        def validate(value)
          Validation.new(name, type, value, options)
        end

        private

        def check_options!
          check_type!
          check_required!
          check_default!
          check_min_max!
          check_format!
          check_clamp!
        end

        def check_type!
          @type = @type.to_s.strip.downcase

          @type = TYPE_ALIASES[@type] unless TYPE_ALIASES[@type].nil?

          valid_type = AVAILABLE_TYPES.include?(@type)
          raise "Invalid param type: #{@type.inspect}" unless valid_type
        end

        def check_required!
          options[:required] = (options[:required] == true)
        end

        def check_default!
          return if options[:default].nil?

          # TODO: check default value type
        end

        def check_min_max!
          check_min!
          check_max!

          return if options[:min].nil? || options[:max].nil?

          raise 'Invalid min-max range' unless options[:min] <= options[:max]
        end

        def check_min!
          min = options[:min]
          return if min.nil?

          raise 'Invalid minimum' unless min.is_a?(Integer) || min.is_a?(Float)
        end

        def check_max!
          max = options[:max]
          return if max.nil?

          raise 'Invalid maximum' unless max.is_a?(Integer) || max.is_a?(Float)
        end

        def check_format!
          return if options[:format].nil?

          raise 'Invalid format' unless options[:format].is_a?(Regexp)
        end

        def check_clamp!
          return if options[:clamp].nil?

          raise 'Invalid clamp' unless options[:clamp].is_a?(Array)
          raise 'Invalid clamp range' unless options[:clamp].first.to_i < options[:clamp].last.to_i
        end
      end
    end
  end
end
