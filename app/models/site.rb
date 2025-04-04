class Site < ApplicationRecord
  belongs_to :user
  has_many :documents, dependent: :destroy

  validates :name, presence: true
  validates :location, presence: true
  validates :primary_url, presence: true
  validates :primary_url, uniqueness: {scope: :user_id}
  validates :name, uniqueness: {scope: [:location, :user_id]}
  validate :ensure_safe_url

  def website
    return nil if primary_url.blank?
    primary_url.sub(/^https?:\/\//, "").sub(/\/$/, "")
  end

  def s3_endpoint_prefix
    return nil if primary_url.blank?

    uri = URI.parse(primary_url.strip)
    host = uri.host.downcase
    host.gsub(/[^a-z0-9]/, "-").squeeze("-").gsub(/^-|-$/, "")
  end

  def s3_endpoint
    return nil if s3_endpoint_prefix.nil?
    File.join(S3_BUCKET, s3_endpoint_prefix)
  end

  def s3_key_for(filename)
    File.join(s3_endpoint_prefix, filename)
  end

  def as_json(options = {})
    super.except("user_id", "created_at", "updated_at")
      .merge("s3_endpoint" => s3_endpoint)
  end

  def discover_documents!(document_data)
    created_or_updated = []
    total_length = document_data.length
    row_count = 1
    document_data.each do |data|
      print "\rProcessing document #{row_count}/#{total_length}\r"
      url = data[:url]
      modification_date = data[:modification_date]

      existing_document = documents.find_by("url = ?", url)

      if existing_document
        if existing_document.modification_date.to_i != modification_date.to_i
          # Document has changed, reset statuses
          existing_document.update! attributes_from(data).reverse_merge(
            file_name: clean_string(data[:file_name]) || existing_document.file_name
          )
        end
        created_or_updated << existing_document
      else
        begin
          if (new_doc = documents.create!(attributes_from(data).reverse_merge(
            file_name: clean_string(data[:file_name]) || File.basename(URI.parse(url).path)
          )))
            created_or_updated << new_doc
          end
        rescue ActiveRecord::RecordInvalid => e
          puts "Skipping error: #{e.message}"
        end
      end
      row_count += 1
    end
    # Clear inline message.
    puts
    created_or_updated
  end

  def process_csv_documents(csv_content)
    documents = []
    skipped = 0
    csv = CSV.new(StringIO.new(csv_content), headers: true)
    csv.each do |row|
      # Encode URL while preserving basic URL structure
      encoded_url = URI.encode_www_form_component(row["url"])
        .gsub("%3A", ":")  # Restore colons
        .gsub("%2F", "/")  # Restore forward slashes

      # Parse file size (remove KB suffix and convert to float)
      file_size = row["file_size"]&.gsub("KB", "")&.strip&.to_f

      # Parse source from CSV - handle the ['url'] format
      source = if row["source"]
        # Extract URLs from the string
        urls = row["source"].scan(/'([^']+)'/).flatten
        urls.empty? ? nil : urls
      end
      documents << {
        url: encoded_url,
        file_name: row["file_name"],
        file_size: file_size,
        author: row["author"],
        subject: row["subject"],
        pdf_version: row["version"],
        keywords: row["keywords"],
        creation_date: row["creation_date"],
        modification_date: row["last_modified_date"],
        producer: row["producer"],
        source: source,
        predicted_category: row["predicted_category"],
        predicted_category_confidence: row["predicted_category_confidence"],
        number_of_pages: row["number_of_pages"]&.to_i
      }
    rescue URI::InvalidURIError => e
      puts "Skipping invalid URL: #{row["url"]}"
      puts "Error: #{e.message}"
      skipped += 1
    end

    created_docs = discover_documents!(documents)
    puts "Created/Updated #{created_docs.size} documents for #{name}"
    puts "Skipped #{skipped} documents due to invalid URLs" if skipped > 0
  end

  private

  def attributes_from(data)
    {
      document_category: data[:predicted_category],
      document_category_confidence: data[:predicted_category_confidence],
      url: data[:url],
      modification_date: data[:modification_date],
      file_size: data[:file_size],
      author: clean_string(data[:author]),
      subject: clean_string(data[:subject]),
      keywords: clean_string(data[:keywords]),
      creation_date: data[:creation_date],
      producer: clean_string(data[:producer]),
      pdf_version: clean_string(data[:pdf_version]),
      source: if data[:source].nil?
                nil
              else
                data[:source].is_a?(Array) ? data[:source].to_json : [data[:source]].to_json
              end,
      number_of_pages: data[:number_of_pages],
      document_status: "discovered"
    }
  end

  def clean_string(str)
    return nil if str.nil?
    str.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
  end

  def ensure_safe_url
    return if primary_url.blank?

    uri = URI.parse(primary_url.strip)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      errors.add(:primary_url, "must be a valid http or https URL")
    end
  rescue URI::InvalidURIError
    errors.add(:primary_url, "is not a valid URL")
  end
end
