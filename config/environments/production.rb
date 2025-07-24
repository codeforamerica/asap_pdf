require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true

  config.public_file_server.headers = {"cache-control" => "public, max-age=#{1.year.to_i}"}

  config.active_storage.service = :local
  config.assume_ssl = true
  config.force_ssl = true

  config.action_dispatch.default_headers = {
    "X-Forwarded-Proto" => "https"
  }

  config.ssl_options = {redirect: {exclude: ->(request) { request.path == "/up" }}}

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)

  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ENDPOINT"),
    port: 587,
    domain: 'demo.codeforamerica.ai',
    user_name: ENV.fetch("SMTP_USER"),
    password: ENV.fetch("SMTP_PASSWORD"),
    authentication: 'plain'
  }
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default_url_options = { host: 'demo.codeforamerica.ai' }

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]
end
