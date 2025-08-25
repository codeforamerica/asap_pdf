class ConfigurationsController < AuthenticatedController
  include Access

  before_action :ensure_user_site_admin

  # This form is only for local development.
  # Python components expect to use staging keys for local development.
  ASAP_API_USER = "asap-pdf/staging/RAILS_API_USER"
  ASAP_API_PASSWORD = "asap-pdf/staging/RAILS_API_PASSWORD"
  GOOGLE_API_SECRET_NAME = "asap-pdf/staging/GOOGLE_AI_KEY"
  ANTHROPIC_API_SECRET_NAME = "asap-pdf/staging/ANTHROPIC_KEY"
  GOOGLE_EVAL_SERVICE_ACCOUNT_CREDS = "asap-pdf/staging/GOOGLE_SERVICE_ACCOUNT"
  GOOGLE_EVAL_SHEET_ID = "asap-pdf/staging/GOOGLE_SHEET_ID_EVALUATION"

  def initialize
    super
    @secret_manager = AwsLocalSecretManager.new
    @secret_names = Rails.configuration.local_secret_names
  end

  def edit
    @config = {
      localstack_not_reachable: false
    }
    response = @secret_manager.get_secret!(@secret_names[:google_api])
    @config["google_ai_api_key"] = response.secret_string if response.present?
    response = @secret_manager.get_secret!(@secret_names[:anthropic_api])
    @config["anthropic_api_key"] = response.secret_string if response.present?
    response = @secret_manager.get_secret!(@secret_names[:google_eval_service_account])
    @config["google_evaluation_service_account_credentials"] = response.secret_string if response.present?
    response = @secret_manager.get_secret!(@secret_names[:google_eval_sheet_id])
    @config["google_evaluation_sheet_id"] = response.secret_string if response.present?
  rescue Seahorse::Client::NetworkingError
    @config["localstack_not_reachable"] = true
  end

  def update
    @secret_manager.set_secret!(@secret_names[:google_api], params.dig(:config, :google_ai_api_key))
    @secret_manager.set_secret!(@secret_names[:anthropic_api], params.dig(:config, :anthropic_api_key))
    @secret_manager.set_secret!(@secret_names[:asap_api_user], Rails.application.credentials.config[:api_user])
    @secret_manager.set_secret!(@secret_names[:asap_api_password], Rails.application.credentials.config[:api_password])
    @secret_manager.set_secret!(@secret_names[:google_eval_service_account], params.dig(:config, :google_evaluation_service_account_credentials))
    @secret_manager.set_secret!(@secret_names[:google_eval_sheet_id], params.dig(:config, :google_evaluation_sheet_id))
    redirect_to edit_configuration_path, notice: "Configuration updated successfully. API user set to Rails config values."
  rescue => e
    redirect_to edit_configuration_path, alert: "Error updating configuration: #{e.message}"
  end
end
