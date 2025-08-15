class ConfigurationsController < AuthenticatedController
  include Access

  before_action :ensure_user_site_admin

  ASAP_API_USER = "/asap-pdf/production/RAILS_API_USER-20250813211406164500000014"
  ASAP_API_PASSWORD = "/asap-pdf/production/RAILS_API_PASSWORD-20250813211406036600000010"

  GOOGLE_API_SECRET_NAME = "/asap-pdf/production/GOOGLE_AI_KEY-2025081321140643510000001a"
  ANTHROPIC_API_SECRET_NAME = "/asap-pdf/production/ANTHROPIC_KEY-20250813211406404500000018"
  GOOGLE_EVAL_SERVICE_ACCOUNT_CREDS = "/asap-pdf/production/GOOGLE_SERVICE_ACCOUNT-20250813211406301100000016"
  GOOGLE_EVAL_SHEET_ID = "/asap-pdf/production/GOOGLE_SHEET_ID_EVALUATION-2025081321140563650000000c"

  def initialize
    super
    @secret_manager = AwsLocalSecretManager.new
  end

  def edit
    @config = {
      localstack_not_reachable: false
    }
    response = @secret_manager.get_secret!(GOOGLE_API_SECRET_NAME)
    @config["google_ai_api_key"] = response.secret_string if response.present?
    response = @secret_manager.get_secret!(ANTHROPIC_API_SECRET_NAME)
    @config["anthropic_api_key"] = response.secret_string if response.present?
    response = @secret_manager.get_secret!(GOOGLE_EVAL_SERVICE_ACCOUNT_CREDS)
    @config["google_evaluation_service_account_credentials"] = response.secret_string if response.present?
    response = @secret_manager.get_secret!(GOOGLE_EVAL_SHEET_ID)
    @config["google_evaluation_sheet_id"] = response.secret_string if response.present?
  rescue Seahorse::Client::NetworkingError
    @config["localstack_not_reachable"] = true
  end

  def update
    @secret_manager.set_secret!(GOOGLE_API_SECRET_NAME, params[:config][:google_ai_api_key])
    @secret_manager.set_secret!(ANTHROPIC_API_SECRET_NAME, params[:config][:anthropic_api_key])
    @secret_manager.set_secret!(ASAP_API_USER, Rails.application.credentials.config[:api_user])
    @secret_manager.set_secret!(ASAP_API_PASSWORD, Rails.application.credentials.config[:api_password])
    @secret_manager.set_secret!(GOOGLE_EVAL_SERVICE_ACCOUNT_CREDS, params[:config][:google_evaluation_service_account_credentials])
    @secret_manager.set_secret!(GOOGLE_EVAL_SHEET_ID, params[:config][:google_evaluation_sheet_id])
    redirect_to edit_configuration_path, notice: "Configuration updated successfully. API user set to Rails config values."
  rescue => e
    redirect_to edit_configuration_path, alert: "Error updating configuration: #{e.message}"
  end
end
