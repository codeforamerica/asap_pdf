class AwsS3Manager
  def initialize
    @s3_client = if Rails.env.development?
      Aws::S3::Client.new(
        endpoint: "http://localhost:4566",
        account_id: "none",
        access_key_id: "none",
        secret_access_key: "none",
        region: "us-east-1",
        force_path_style: true,
        stub_responses: false
      )
    else
      Aws::S3::Client.new
    end
  end

  def write_file!(bucket_name, key, file_path, content_type = nil, metadata = {})
    File.open(file_path, "rb") do |file|
      @s3_client.put_object(
        bucket: bucket_name,
        key: key,
        body: file,
        content_type: content_type || "application/octet-stream",
        metadata: metadata
      )
    end
  end

  def get_files!(bucket_name, key)
    prefix = key.end_with?("/") ? key : "#{key}/"
    params = {
      bucket: bucket_name,
      prefix: prefix,
      max_keys: 100
    }
    response = @s3_client.list_objects_v2(params)
    response.contents.sort_by(&:last_modified).reverse
  end

  def get_metadata!(bucket_name, key)
    head_response = @s3_client.head_object(
      bucket: bucket_name,
      key: key
    )
    return {} unless head_response.metadata.present?
    head_response.metadata
  end

  def get_object!(bucket_name, key)
    @s3_client.get_object(bucket: bucket_name, key: key)
  end
end
