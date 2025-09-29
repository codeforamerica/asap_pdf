class ConfigurationsController < AuthenticatedController
  include Access

  before_action :ensure_user_site_admin

  def initialize
    super
    @config = {
      google_ai_api_key: nil,
      anthropic_api_key: nil,
      openai_api: nil,
      google_evaluation_service_account_credentials: nil,
      google_evaluation_sheet_id: nil,
      localstack_not_reachable: false
    }

    @secret_manager = AwsLocalSecretManager.new

    if Rails.configuration.respond_to?(:local_secret_names)
      @secret_names = Rails.configuration.local_secret_names
    else
      @config["localstack_not_reachable"] = true
    end
  end

  def edit
    unless @config["localstack_not_reachable"]
      begin
        response = @secret_manager.get_secret!(@secret_names[:google_api])
        @config["google_ai_api_key"] = response.secret_string if response.present?
        response = @secret_manager.get_secret!(@secret_names[:anthropic_api])
        @config["anthropic_api_key"] = response.secret_string if response.present?
        response = @secret_manager.get_secret!(@secret_names[:openai_api])
        @config["openai_api"] = response.secret_string if response.present?
        response = @secret_manager.get_secret!(@secret_names[:google_eval_service_account])
        @config["google_evaluation_service_account_credentials"] = response.secret_string if response.present?
        response = @secret_manager.get_secret!(@secret_names[:google_eval_sheet_id])
        @config["google_evaluation_sheet_id"] = response.secret_string if response.present?
      rescue Seahorse::Client::NetworkingError
        @config["localstack_not_reachable"] = true
      end
    end
  end

  def update
    @secret_manager.set_secret!(@secret_names[:google_api], params.dig(:config, :google_ai_api_key))
    @secret_manager.set_secret!(@secret_names[:anthropic_api], params.dig(:config, :anthropic_api_key))
    @secret_manager.set_secret!(@secret_names[:openai_api], params.dig(:config, :openai_api))
    @secret_manager.set_secret!(@secret_names[:asap_api_user], Rails.application.credentials.config[:api_user])
    @secret_manager.set_secret!(@secret_names[:asap_api_password], Rails.application.credentials.config[:api_password])
    @secret_manager.set_secret!(@secret_names[:google_eval_service_account], params.dig(:config, :google_evaluation_service_account_credentials))
    @secret_manager.set_secret!(@secret_names[:google_eval_sheet_id], params.dig(:config, :google_evaluation_sheet_id))
    redirect_to edit_configuration_path, notice: "Configuration updated successfully. API user set to Rails config values."
  rescue => e
    redirect_to edit_configuration_path, alert: "Error updating configuration: #{e.message}"
  end
end
