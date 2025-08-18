class AwsLocalSecretManager
  def initialize
    @secret_manager = Aws::SecretsManager::Client.new(
      endpoint: "http://localstack:4566",
      account_id: "none",
      access_key_id: "none",
      secret_access_key: "none",
      region: "us-east-1"
    )
  end

  def get_secret!(secret_name)
    @secret_manager.get_secret_value({
      secret_id: secret_name
    })
  rescue Aws::SecretsManager::Errors::ResourceNotFoundException
    nil
  end

  def secret_exists?(secret_name)
    secrets = @secret_manager.list_secrets
    secrets.to_h[:secret_list].each do |secret|
      if secret_name == secret[:name]
        return true
      end
    end
    false
  end

  def set_secret!(secret_name, value)
    if !secret_exists?(secret_name)
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
