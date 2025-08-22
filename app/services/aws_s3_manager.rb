class AwsS3Manager
  def initialize
    if Rails.env.development?
      @s3_client = Aws::S3::Client.new(
        endpoint: "http://localhost:4566",
        account_id: "none",
        access_key_id: "none",
        secret_access_key: "none",
        region: "us-east-1",
        force_path_style: true,
        stub_responses: false
      )
    else
      @s3_client = Aws::S3::Client.new
    end
  end

  def write_file(bucket_name, key, file_path, content_type = nil)
    File.open(file_path, 'rb') do |file|
      @s3_client.put_object(
        bucket: bucket_name,
        key: key,
        body: file,
        content_type: content_type || 'application/octet-stream'
      )
    end
  end

  def get_files(bucket_name, key)
    prefix = key.end_with?('/') ? key : "#{key}/"
    bucket = @s3_client.bucket(bucket_name)
    objects = bucket.objects(prefix: prefix)
    objects.map(&:key)
  end
end