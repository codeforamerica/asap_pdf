class Document < ApplicationRecord
  DEFAULT_DECISION = "Needs Decision".freeze
  IN_REVIEW_DECISION = "In Review".freeze
  DONE_DECISION = "Done".freeze
  ARCHIVE_DECISION = "Archive".freeze
  REMOVE_DECISION = "Remove".freeze
  CONVERT_DECISION = "Convert".freeze
  REMEDIATE_DECISION = "Remediate".freeze
  LEAVE_DECISION = "Leave".freeze

  DECISION_TYPES = {
    DEFAULT_DECISION => {"label" => "Needs Decision"},
    IN_REVIEW_DECISION => {"label" => "PDF is in Review"},
    DONE_DECISION => {
      "label" => "Done",
      "children" => {
        ARCHIVE_DECISION => {"label" => "Place PDF in Archive Section"},
        REMOVE_DECISION => {"label" => "Remove PDF from Website"},
        CONVERT_DECISION => {"label" => "Convert PDF to HTML"},
        REMEDIATE_DECISION => {"label" => "Remediate PDF"},
        LEAVE_DECISION => {"label" => "Leave PDF As-is"}
      }
    }
  }

  CONTENT_TYPES = %w[Agreement Agenda Brochure Diagram Flyer Form Job Letter Policy Slides Press Procurement Notice Report Spreadsheet].freeze

  AI_SUGGESTION_EXCEPTION, AI_SUGGESTION_NO_EXCEPTION = %w[Might\ be\ exception Likely\ not\ exception]

  SIMPLE_STATUS = "Simple".freeze
  COMPLEX_STATUS = "Complex".freeze

  COMPLEXITIES = [SIMPLE_STATUS, COMPLEX_STATUS].freeze

  belongs_to :site

  has_many :document_inferences

  before_save :set_complexity

  has_paper_trail versions: {scope: -> { order(created_at: :desc) }}

  validates :file_name, presence: true
  validates :url, presence: true, format: {with: URI::DEFAULT_PARSER.make_regexp}
  validates :document_status, presence: true, inclusion: {in: %w[discovered downloaded]}
  validates :document_category, inclusion: {in: CONTENT_TYPES}
  validates :accessibility_recommendation, inclusion: {in: -> { get_decision_types }}, presence: true
  validates :complexity, inclusion: {in: COMPLEXITIES}, allow_nil: true

  before_validation :set_defaults

  scope :by_filename, ->(filename) {
    return all if filename.blank?
    filename = "%#{filename.gsub(/[\s_-]+/, "%")}%"
    where("url ILIKE ? OR file_name ILIKE ?", "%#{filename}%", "%#{filename}%")
  }

  scope :by_category, ->(category) {
    return all if category.blank?
    where(document_category: category)
  }

  scope :by_decision_type, ->(decision_type) {
    if decision_type.present?
      if DECISION_TYPES[decision_type].present? && DECISION_TYPES[decision_type]["children"].present?
        decision_type = DECISION_TYPES[decision_type]["children"].keys
      end
      where(accessibility_recommendation: decision_type)
    else
      where(accessibility_recommendation: DEFAULT_DECISION)
    end
  }

  scope :by_department, ->(department) {
    return all if department.blank?
    department = (department == "None") ? [nil, ""] : department
    where(department: department)
  }

  scope :by_complexity, ->(complexity) {
    return all if complexity.blank?
    complexity = (complexity == "None") ? [nil, ""] : complexity
    where(complexity: complexity)
  }

  scope :by_date_range, ->(start_date, end_date) {
    scope = all
    scope = scope.where("modification_date >= ?", start_date) if start_date.present?
    scope = scope.where("modification_date <= ?", end_date) if end_date.present?
    scope
  }

  def self.get_decision_types
    options = {}
    Document::DECISION_TYPES.each do |key, item|
      if item["children"].present?
        item["children"].each do |child_key, child|
          options[child_key] = child["label"]
        end
      else
        options[key] = item["label"]
      end
    end
    options
  end

  def self.get_content_type_options
    Document::CONTENT_TYPES.map { |c| [c.to_s.titleize, c] }
  end

  def self.get_complexity_options
    Document::COMPLEXITIES.map { |c| [c.to_s.titleize, c] }
  end

  def modification_year
    if modification_date.present?
      modification_date.strftime("%Y")
    else
      "Unknown"
    end
  end

  def summary
    summary = document_inferences.find_by(inference_type: "summary")
    summary.present? ? summary.inference_value : nil
  end

  def last_changed_by_human?(field)
    field_versions = versions.where("object_changes LIKE ?", "%#{field}%")
    last_change = field_versions.order(created_at: :desc).first
    last_change.present? && last_change.whodunnit.present?
  end

  def accessibility_recommendation_from_inferences
    # Otherwise calculate based on inferences
    if document_inferences.any?
      exceptions = self.exceptions
      if exceptions.any?
        AI_SUGGESTION_EXCEPTION
      else
        AI_SUGGESTION_NO_EXCEPTION
      end
    end
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

  def file_name
    return nil if self[:file_name].nil?
    # If we have a value make unescape before displaying.
    unescaped_file_name = URI::DEFAULT_PARSER.unescape(self[:file_name])
    # Filenames, cannot have characters with special url-meaning.
    unescaped_file_name.delete("?")
      .delete("/")
  end

  def url
    self[:url]&.sub("http://", "https://")
  end

  def normalized_url
    decoded_url = recursive_decode(url)
    # Add any additional oddities here.
    decoded_url = decoded_url.tr("\\", "/").tr("+", " ")
    URI::DEFAULT_PARSER.escape(decoded_url)
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
      if Rails.env.to_s != "production"
        lambda_manager = AwsLambdaManager.new(function_url: "http://localhost:9002/2015-03-31/functions/function/invocations")
        api_host = "http://host.docker.internal:3000"
      else
        lambda_manager = AwsLambdaManager.new(function_name: "asap-pdf-document-inference-production")
        api_host = "https://demo.codeforamerica.ai"
      end
      payload = {
        model_name: "gemini-2.0-flash",
        documents: [{id: id, title: file_name, url: normalized_url, purpose: document_category}],
        page_limit: 7,
        inference_type: "summary",
        asap_endpoint: "#{api_host}/api/documents/#{id}/inference"
      }
      begin
        response = lambda_manager.invoke_lambda!(payload)
        begin
          json_body = JSON.parse(response.body)
          body = json_body["body"]
          status = json_body["statusCode"]
        rescue JSON::ParserError
          body = response.body
          status = response.code
        end
        if Integer(status) != 200
          raise StandardError, "Inference failed: #{body}"
        end
      end
    end
  end

  def inference_recommendation!
    if Rails.env.to_s != "production"
      lambda_manager = AwsLambdaManager.new(function_url: "http://localhost:9002/2015-03-31/functions/function/invocations")
      api_host = "http://host.docker.internal:3000"
    else
      lambda_manager = AwsLambdaManager.new(function_name: "asap-pdf-document-inference-production")
      api_host = "https://demo.codeforamerica.ai"
    end
    payload = {
      model_name: "gemini-2.5-pro-preview-03-25",
      documents: [{id: id, title: file_name, url: normalized_url, purpose: document_category, creation_date: creation_date}],
      page_limit: 7,
      inference_type: "exception",
      asap_endpoint: "#{api_host}/api/documents/#{id}/inference"
    }
    begin
      response = lambda_manager.invoke_lambda!(payload)
      begin
        json_body = JSON.parse(response.body)
        body = json_body["body"]
        status = json_body["statusCode"]
      rescue JSON::ParserError
        body = response.body
        status = response.code
      end
      if Integer(status) != 200
        raise StandardError, "Inference failed: #{body}"
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

  def recursive_decode(url)
    decoded_url = URI::DEFAULT_PARSER.unescape(url)
    if url != decoded_url
      decoded_url = recursive_decode(decoded_url)
    end
    decoded_url
  end

  def storage_config
    @storage_config ||= begin
      config = Rails.application.config.active_storage.service_configurations[Rails.env.to_s]
      raise "S3 storage configuration not found for #{Rails.env}" unless config
      config.symbolize_keys
    end
  end

  def set_defaults
    self.document_status = "discovered" unless document_status
    self.accessibility_recommendation = DEFAULT_DECISION unless accessibility_recommendation
  end

  def set_complexity
    self.complexity = if document_category == "Form" || (number_of_tables || 0) > 0 || (number_of_images || 0) > 0
      COMPLEX_STATUS
    else
      SIMPLE_STATUS
    end
  end
end
