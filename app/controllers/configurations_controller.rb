class ConfigurationsController < AuthenticatedController
  include Access

  before_action :ensure_user_admin

  GOOGLE_API_SECRET_NAME = "asap-pdf/production/GOOGLE_AI_KEY"
  ANTHROPIC_API_SECRET_NAME = "asap-pdf/production/ANTHROPIC_KEY"

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
  rescue Seahorse::Client::NetworkingError
    @config["localstack_not_reachable"] = true
  end

  def update
    @secret_manager.set_secret!(GOOGLE_API_SECRET_NAME, params[:config][:google_ai_api_key])
    @secret_manager.set_secret!(ANTHROPIC_API_SECRET_NAME, params[:config][:anthropic_api_key])
    redirect_to edit_configuration_path, notice: "Configuration updated successfully"
  rescue => e
    redirect_to edit_configuration_path, alert: "Error updating configuration: #{e.message}"
  end
end
