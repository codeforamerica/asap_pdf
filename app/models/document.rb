class Document < ApplicationRecord
  extend UrlDecodedAttributeHelper

  belongs_to :site
  has_many :workflow_histories, class_name: "DocumentWorkflowHistory"
  has_many :document_inferences

  has_paper_trail versions: {scope: -> { order(created_at: :desc) }}

  url_decoded_attribute :file_name
  url_decoded_attribute :url

  scope :by_status, ->(status) {
    case status
    when "in_review"
      where(status: "in_review")
    when "done"
      where(status: "done")
    when "", nil
      where("status IS NULL OR status = ?", "")
    else
      all
    end
  }

  scope :by_filename, ->(filename) {
    return all if filename.blank?
    where("file_name ILIKE ?", "%#{filename}%")
  }

  scope :by_category, ->(category) {
    return all if category.blank?
    where(document_category: category)
  }

  scope :by_date_range, ->(start_date, end_date) {
    scope = all
    scope = scope.where("modification_date >= ?", start_date) if start_date.present?
    scope = scope.where("modification_date <= ?", end_date) if end_date.present?
    scope
  }

  DEFAULT_DOCUMENT_CATEGORY, DEFAULT_ACCESSIBILITY_RECOMMENDATION = %w[Other Unknown].freeze

  CONTENT_TYPES = [
    DEFAULT_DOCUMENT_CATEGORY, "Agreement", "Agenda", "Brochure", "Diagram", "Flyer", "Form", "Form Instructions",
    "Job Announcement", "Job Description", "Letter", "Map", "Memo", "Policy", "Slides",
    "Press", "Procurement", "Notice", "Report", "Spreadsheet", "Unknown"
  ].freeze

  LEAVE_ACCESSIBILITY_RECOMMENDATION, REMEDIATE_ACCESSIBILITY_RECOMMENDATION = %w[Leave Remediate].freeze

  DECISION_TYPES = [DEFAULT_ACCESSIBILITY_RECOMMENDATION, LEAVE_ACCESSIBILITY_RECOMMENDATION,
    REMEDIATE_ACCESSIBILITY_RECOMMENDATION, "Convert", "Remove"].freeze

  validates :file_name, presence: true
  validates :url, presence: true, format: {with: URI::DEFAULT_PARSER.make_regexp}
  validates :document_status, presence: true, inclusion: {in: %w[discovered downloaded]}
  validates :document_category, inclusion: {in: CONTENT_TYPES}, allow_nil: true
  validates :accessibility_recommendation, inclusion: {in: DECISION_TYPES}, allow_nil: true

  before_validation :set_defaults

  def accessibility_recommendation
    # Find versions that changed the accessibility_recommendation field
    accessibility_versions = versions.where("object_changes LIKE ?", "%accessibility_recommendation%")
    # Get the most recent version that changed this field
    last_change = accessibility_versions.order(created_at: :desc).first

    # Check if there was a change and if the user was non-nil
    return self[:accessibility_recommendation] if last_change.present? && last_change.whodunnit.present?
    accessibility_recommendation_from_inferences
  end

  def accessibility_recommendation_from_inferences
    # Otherwise calculate based on inferences
    if document_inferences.any?
      exceptions = self.exceptions
      if exceptions.any?
        return LEAVE_ACCESSIBILITY_RECOMMENDATION
      else
        return REMEDIATE_ACCESSIBILITY_RECOMMENDATION
      end
    end
    DEFAULT_ACCESSIBILITY_RECOMMENDATION
  end

  def exceptions(include_value_check = true)
    selected_inferences = document_inferences.select do |inference|
      base_condition = inference.inference_type.include?("exception")
      value_condition = inference.inference_value.to_s.downcase == "true"

      include_value_check ? (base_condition && value_condition) : base_condition
    end

    # Create an array of the keys to determine their position
    type_order = DocumentInference::INFERENCE_TYPES.keys.map(&:to_s)

    # Sort the selected inferences based on their position in the INFERENCE_TYPES hash
    selected_inferences.sort_by do |inference|
      index = type_order.index(inference.inference_type)
      # Use the index if found, otherwise place at the end
      index.nil? ? type_order.length : index
    end
  end

  def s3_path
    "#{site.s3_endpoint_prefix}/#{id}/document.pdf"
  end

  def s3_bucket
    @s3_bucket ||= Aws::S3::Resource.new(
      access_key_id: storage_config[:access_key_id],
      secret_access_key: storage_config[:secret_access_key],
      region: storage_config[:region],
      endpoint: storage_config[:endpoint],
      force_path_style: storage_config[:force_path_style]
    ).bucket(storage_config[:bucket])
  end

  def s3_object
    s3_bucket.object(s3_path)
  end

  def file_versions
    s3_bucket.object_versions(prefix: s3_path)
  end

  def latest_file
    file_versions.first
  end

  def file_version(version_id)
    s3_object.get(version_id: version_id)
  end

  def version_metadata(version)
    {
      version_id: version.version_id,
      modification_date: version.modification_date,
      size: version.size,
      etag: version.etag
    }
  end

  def inference_summary!
    if summary.nil?
      endpoint_url = "http://localhost:9000/2015-03-31/functions/function/invocations"
      payload = {
        model_name: "gemini-1.5-pro-latest",
        document_url: url,
        page_limit: 7
      }.to_json
      begin
        response = RestClient.post(endpoint_url, payload, {content_type: :json, accept: :json})
        json_body = JSON.parse(response.body)
        if json_body["statusCode"] == 200
          self.summary = '"' + json_body["body"] + '"'
        else
          raise StandardError.new("Inference failed: #{json_body["body"]}")
        end
        summary
      end
    end
  end

  def inference_recommendation!
    if exceptions.none?
      endpoint_url = "http://localhost:9001/2015-03-31/functions/function/invocations"
      payload = {
        model_name: "gemini-2.0-pro-exp-02-05",
        documents: [{id: id, title: file_name, url: url, purpose: document_category}],
        page_limit: 7
      }.to_json
      begin
        response = RestClient.post(endpoint_url, payload, {content_type: :json, accept: :json})
        response_json = JSON.parse(response.body)
        if response_json["statusCode"] != 200
          raise StandardError, response_json["body"]
        end
      end
    end
  end

  def source
    value = read_attribute(:source)
    return nil if value.nil?

    begin
      JSON.parse(value)
    rescue JSON::ParserError
      value
    end
  end

  def source=(value)
    # If value is already a JSON string, store as-is
    # Otherwise convert to JSON
    json_value = if value.is_a?(String)
      begin
        # Try parsing to validate it's proper JSON
        JSON.parse(value)
        value # If parsing succeeds, use original string
      rescue JSON::ParserError
        value.to_json # Not JSON, so convert it
      end
    else
      value.to_json
    end
    write_attribute(:source, json_value)
  end

  def primary_source
    urls = source
    return nil if urls.nil?

    urls.is_a?(Array) ? urls.first : urls
  end

  private

  def storage_config
    @storage_config ||= begin
      config = Rails.application.config.active_storage.service_configurations[Rails.env.to_s]
      raise "S3 storage configuration not found for #{Rails.env}" unless config
      config.symbolize_keys
    end
  end

  def set_defaults
    self.document_status = "discovered" unless document_status
  end
end
