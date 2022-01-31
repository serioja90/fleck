# frozen_string_literal: true

module Fleck
  module Core
    # Open `Consumer` class in order to define consumer helpers
    class Consumer
      # Define methods for 1xx codes
      information_method :continue!, 100
      information_method :switching_protocols!, 101
      information_method :processing!, 102
      information_method :early_hints!, 103

      # Define methods for 2xx codes
      success_method :ok!, 200
      success_method :created!, 201
      success_method :accepted!, 202
      success_method :non_authoritative_information!, 203
      success_method :no_content!, 204
      success_method :reset_content!, 205
      success_method :partial_content!, 206
      success_method :multi_status!, 207
      success_method :already_reported!, 208
      success_method :im_used!, 226

      # Define methods for 3xx codes
      redirect_method :multiple_choice!, 300
      redirect_method :moved_permanently!, 301
      redirect_method :found!, 302
      redirect_method :see_other!, 303
      redirect_method :not_modified!, 304
      redirect_method :use_proxy!, 305
      redirect_method :unused!, 306
      redirect_method :temporary_redirect!, 307
      redirect_method :permanent_redirect!, 308

      # Define methods for 4xx errors
      error_method :bad_request!, 400, 'Bad Request'
      error_method :unauthorized!, 401, 'Unauthorized'
      error_method :payment_required!, 402, 'Payment Required'
      error_method :forbidden!, 403, 'Forbidden'
      error_method :not_found!, 404, 'Not Found'
      error_method :method_not_allowed!, 405, 'Method Not Allowed'
      error_method :not_acceptable!, 406, 'Not Acceptable'
      error_method :proxy_authentication_required!, 407, 'Proxy Authentication Required'
      error_method :request_timeout!, 408, 'Request Timeout'
      error_method :conflict!, 409, 'Conflict'
      error_method :gone!, 410, 'Gone'
      error_method :length_required!, 411, 'Length Required'
      error_method :precondition_failed!, 412, 'Precondition Failed'
      error_method :payload_too_large!, 413, 'Payload Too Large'
      error_method :uri_too_long!, 414, 'URI Too Long'
      error_method :unsupported_media_type!, 415, 'Unsupported Media Type'
      error_method :range_not_satisfiable!, 416, 'Range Not Satisfiable'
      error_method :expectation_failed!, 417, 'Expectation Failed'
      error_method :im_a_teapot!, 418, "I'm a teapot"
      error_method :misdirected_request!, 421, 'Misdirected Request'
      error_method :unprocessable_entity!, 422, 'Unprocessable Entity'
      error_method :locked!, 423, 'Locked'
      error_method :failed_dependency!, 424, 'Failed Dependency'
      error_method :too_early!, 425, 'Too Early'
      error_method :upgrade_required!, 426, 'Upgrade Required'
      error_method :precondition_required!, 428, 'Precondition Required'
      error_method :too_many_requests!, 429, 'Too Many Requests'
      error_method :request_header_fields_too_large!, 431, 'Request Header Fields Too Large'
      error_method :unavailable_for_legal_reasons!, 451, 'Unavailable For Legal Reasons'

      # Define methods for 5xx errors
      error_method :internal_server_error!, 500, 'Internal Server Error'
      error_method :not_implemented!, 501, 'Not Implemented'
      error_method :bad_gateway!, 502, 'Bad Gateway'
      error_method :service_unavailable!, 503, 'Service Unavailable'
      error_method :gateway_timeout!, 504, 'Gateway Timeout'
      error_method :http_version_not_supported!, 505, 'HTTP Version Not Supported'
      error_method :variant_also_negotiates!, 506, 'Variant Also Negotiates'
      error_method :insufficient_storage!, 507, 'Insufficient Storage'
      error_method :loop_detected!, 508, 'Loop Detected'
      error_method :not_extended!, 510, 'Not Extended'
      error_method :network_authentication_required!, 511, 'Network Authentication Required'
    end
  end
end
