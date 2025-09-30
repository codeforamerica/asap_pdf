Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?

  config.public_file_server.headers = {"cache-control" => "public, max-age=3600"}

  config.consider_all_requests_local = true
  config.cache_store = :null_store

  config.action_dispatch.show_exceptions = :rescuable
  # config.action_controller.allow_forgery_protection = false

  config.active_storage.service = :test
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = {host: "example.com"}
  config.action_mailer.perform_deliveries = true
  config.action_mailer.default_options = {
    from: "Code for America <admin@ada.codeforamerica.ai>"
  }
  config.active_support.deprecation = :stderr

  config.action_controller.raise_on_missing_callback_actions = true

  config.default_s3_bucket = "asap-pdf-staging-documents"

  config.local_secret_names = {
    asap_api_user: "asap-pdf/staging/RAILS_API_USER",
    asap_api_password: "asap-pdf/staging/RAILS_API_PASSWORD",
    google_api: "asap-pdf/staging/GOOGLE_AI_KEY",
    anthropic_api: "asap-pdf/staging/ANTHROPIC_KEY",
    openai_api: "asap-pdf/staging/OPENAI_KEY",
    google_eval_service_account: "asap-pdf/staging/GOOGLE_SERVICE_ACCOUNT",
    google_eval_sheet_id: "asap-pdf/staging/GOOGLE_SHEET_ID_EVALUATION"
  }
end
