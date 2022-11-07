# frozen_string_literal: true

require 'configatron'

ENV['TZ'] = 'UTC' # set default timezone to UTC

LOG_LEVELS = {
  debug: Logger::DEBUG,
  info: Logger::INFO,
  warn: Logger::WARN,
  error: Logger::ERROR,
  fatal: Logger::FATAL
}.freeze

Config = configatron

# Default service configurations
# ==============================
Config.version  = VERSION
Config.root     = File.expand_path('..', __dir__)
Config.timezone = ENV['TZ']
Config.env      = ENV.fetch('RAKE_ENV', 'production')

# Service configurations
# ======================
Config.app_name           = ENV.fetch('APP_NAME', %q(gigi))
Config.title              = ENV.fetch('TITLE', %q(gigi app))
Config.pidfile            = ENV.fetch('PIDFILE', "#{Config.root}/service.pid")
Config.logfile            = ENV.fetch('LOGFILE', "#{Config.root}/log/service.log")
Config.loglevel           = LOG_LEVELS[ENV['LOGLEVEL'].to_s.to_sym] || (ENV['LOGLEVEL'] || Logger::INFO).to_i
Config.concurrency        = ENV.fetch('CONCURRENCY', 2).to_i
Config.interactive        = ENV['INTERACTIVE'].is_true?

# Default database configurations
# ===============================
Config.db.host               = ENV.fetch('DB_HOST', '127.0.0.1')
Config.db.port               = ENV.fetch('DB_PORT', 5432)
Config.db.name               = ENV.fetch('DB_NAME') { Config.env == 'test' ? 'micros_test' : 'micros' }
Config.db.user               = ENV.fetch('DB_USER')
Config.db.pass               = ENV.fetch('DB_PASS')
# For compatibility reasons we'll disable encryption by default
Config.db.sslmode            = ENV.fetch('DB_SSLMODE', 'disable')
Config.db.max_connections    = ENV.fetch('DB_MAX_CONNECTIONS', [Config.concurrency, 4].min)
Config.db.migrate            = ENV['DB_MIGRATE'].is_true?
Config.db.migrations_path    = "#{Config.root}/db/migrations"
Config.db.schema_table       = :gigi_schema_info
# Check if connection is valid before executing the query after 30 seconds of inactivity
Config.db.conn_check_timeout = ENV.fetch('DB_CONN_CHECK_TIMEOUT', 30).to_f

# RabbitMQ configurations
# =======================
Config.rabbitmq.host                        = ENV.fetch('RMQ_HOST', '127.0.0.1')
Config.rabbitmq.hosts                       = ENV.fetch('RMQ_HOSTS').to_s.split(',').map(&:strip)
Config.rabbitmq.port                        = ENV.fetch('RMQ_PORT', 5672)
Config.rabbitmq.vhost                       = ENV.fetch('RMQ_VHOST', '/')
Config.rabbitmq.user                        = ENV.fetch('RMQ_USER', 'guest')
Config.rabbitmq.pass                        = ENV.fetch('RMQ_PASS', 'guest')

# Kafka configs
# =============
Config.kafka.hosts                    = ENV.fetch('KAFKA_HOSTS', 'localhost:9092').split(',').map(&:strip)
Config.kafka.client_id                = ENV.fetch('KAFKA_CLIENT_ID', Config.app_name)
Config.kafka.ssl_enabled              = ENV.fetch('KAFKA_SSL_ENABLED').is_true?
Config.kafka.ssl_ca_cert              = ENV.fetch('KAFKA_SSL_CA_CERT')
Config.kafka.ssl_client_cert          = ENV.fetch('KAFKA_SSL_CLIENT_CERT')
Config.kafka.ssl_client_cert_key      = ENV.fetch('KAFKA_SSL_CLIENT_CERT_KEY')
# Set SASL mechanism for Kafka clients (default: 'plain', but 'scram' is also available)
Config.kafka.sasl_mechanism           = ENV.fetch('KAFKA_MECHANISM', 'plain').downcase
Config.kafka.sasl_username            = ENV.fetch('KAFKA_USERNAME')
Config.kafka.sasl_password            = ENV.fetch('KAFKA_PASSWORD')
