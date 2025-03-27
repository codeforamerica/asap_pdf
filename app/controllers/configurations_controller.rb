class ConfigurationsController < ApplicationController
  GOOGLE_API_SECRET_NAME = "asap-pdf/production/GOOGLE_AI_KEY"
  ANTHROPIC_API_SECRET_NAME = "asap-pdf/production/ANTHROPIC_KEY"

  def initialize
    super
    @secret_manager = Aws::SecretsManager::Client.new(
      endpoint: "http://localhost:4566",
      access_key_id: "none",
      secret_access_key: "none",
      region: "us-east-1"
    )
  rescue NetworkingError
    @secret_manager = nil
  end

  def edit
    @config = {
      localstack_not_reachable: false
    }
    response = get_secret!(GOOGLE_API_SECRET_NAME)
    @config["google_ai_api_key"] = response.secret_string if response.present?
    response = get_secret!(ANTHROPIC_API_SECRET_NAME)
    @config["anthropic_api_key"] = response.secret_string if response.present?
  rescue Seahorse::Client::NetworkingError
    @config["localstack_not_reachable"] = true
  end

  def update
    set_secret!(GOOGLE_API_SECRET_NAME, params[:config][:google_ai_api_key])
    set_secret!(ANTHROPIC_API_SECRET_NAME, params[:config][:anthropic_api_key])
    redirect_to edit_configuration_path, notice: "Configuration updated successfully"
  rescue => e
    redirect_to edit_configuration_path, alert: "Error updating configuration: #{e.message}"
  end

  private

  def get_secret!(secret_name)
    @secret_manager.get_secret_value({
      secret_id: secret_name
    })
  rescue Aws::SecretsManager::Errors::ResourceNotFoundException
    nil
  end

  def set_secret!(secret_name, value)
    if get_secret!(secret_name).nil?
      @secret_manager.create_secret({
        name: secret_name,
        secret_string: value
      })
    else
      @secret_manager.update_secret({
        secret_id: secret_name,
        secret_string: value
      })
    end
  end
end
