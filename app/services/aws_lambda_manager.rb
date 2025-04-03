class AwsLambdaManager
  def initialize(region: "us-east-1", function_name: nil, function_url: nil)
    @region = region
    if function_name.nil? && function_url.nil?
      raise StandardError, "Lambda manager must be instantiated with either a function_name or function_url."
    end
    @function_name = function_name
    @function_url = function_url
    if @function_url.nil?
      lambda_client = Aws::Lambda::Client.new(region: region)
      url_config = lambda_client.get_function_url_config(function_name: function_name)
      @function_url = url_config.function_url
    end
  end

  def invoke_lambda!(payload = {})
    request_body = payload.to_json
    # Parse the URL
    uri = URI.parse(@function_url)
    credentials_provider = Aws::CredentialProviderChain.new.resolve
    # Create a signing request
    signer = Aws::Sigv4::Signer.new(
      service: "lambda",
      region: @region,
      credentials_provider: credentials_provider
    )
    # Sign the request
    signed_headers = signer.sign_request(
      http_method: "POST",
      url: @function_url,
      headers: {
        "Host" => uri.host,
        "Content-Type" => "application/json"
      },
      body: request_body
    )
    # Create the HTTP request
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    request = Net::HTTP::Post.new(uri)
    request.body = request_body
    request.content_type = "application/json"
    # Add the signed headers to the request
    signed_headers.headers.each do |key, value|
      request[key] = value
    end
    # Execute the request
    http.request(request)
  end
end
