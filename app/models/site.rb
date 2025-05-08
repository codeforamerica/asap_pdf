class Site < ApplicationRecord
  has_many :documents, dependent: :destroy
  has_many :users

  validates :name, presence: true, uniqueness: true
  validates :location, presence: true
  validates :primary_url, presence: true, uniqueness: true
  validate :ensure_safe_url

  DEPARTMENT_MAPPING = {
    "Information Management Services" => ["https://www.slc.gov/ims/"],
    "Finance" => ["https://www.slc.gov/finance/"],
    "City Attorney's Office" => ["https://www.slc.gov/attorney/"],
    "Justice Courts" => ["https://www.slc.gov/courts/"],
    "Community and Neighborhoods (CAN)" => ["https://www.slc.gov/can/"],
    "Building Services" => ["https://www.slc.gov/buildingservices/"],
    "Transportation" => ["https://www.slc.gov/transportation/"],
    "Planning Division" => ["https://www.slc.gov/planningdivision", "https://www.slc.gov/planning"],
    "Public Services" => ["https://www.slc.gov/publicservice/"],
    "Public Lands Department" => ["https://www.slc.gov/parks/"],
    "MyStreet" => ["https://www.slc.gov/mystreet/"],
    "Sustainability" => ["https://www.slc.gov/sustainability/"],
    "Department of Economic Development (EconDev)" => ["https://www.slc.gov/ed/"],
    "Public Utilites" => ["https://www.slc.gov/utilities/"],
    "Human Resources" => ["https://www.slc.gov/hr/"],
    "Engineering" => ["https://www.slc.gov/engineering/"],
    "Events" => ["https://www.slc.gov/events/"],
    "Council District 1" => ["https://www.slc.gov/district1/"],
    "Council District 2" => ["https://www.slc.gov/district2/"],
    "Council District 3" => ["https://www.slc.gov/district3/"],
    "Council District 4" => ["https://www.slc.gov/district4/"],
    "Council District 5" => ["https://www.slc.gov/district5/"],
    "Council District 6" => ["https://www.slc.gov/district6/"],
    "Council District 7" => ["https://www.slc.gov/district7/"],
    "City Council Office" => ["https://www.slc.gov/council/"],
    "SLC Calendar" => ["https://www.slc.gov/calendar/"],
    "Boards and Commissions" => ["https://www.slc.gov/boards/"],
    "SLC911" => ["https://www.slc.gov/911/"],
    "Event Permits" => ["https://www.slc.gov/ev/"],
    "Division of Youth and Family" => ["https://www.slc.gov/youthandfamily/"],
    "Emergency Management" => ["https://www.slc.gov/em/"],
    "Historic Preservation" => ["https://www.slc.gov/histroic-preservation/"],
    "Mayor's Office" => ["https://www.slc.gov/mayor/"],
    "Ballpark NEXT" => ["https://www.slc.gov/ballparknext/"],
    "Mayor's Office of Access & Belonging" => ["https://www.slc.gov/access-belonging/"],
    "Housing Stability" => ["https://www.slc.gov/housingstability/", "https://www.slc.gov/hand/"],
    "Workday" => ["https://www.slc.gov/workday/"],
    "Homelessness" => ["https://www.slc.gov/homelessness/"],
    "Urban Forestry" => ["https://www.slc.gov/urban-forestry/"],
    "External" => ["https://www.slcdocs.com"],
    "Community Reinvestment Agency" => ["https://cra.slc.gov"],
    "Police" => ["https://police.slc.gov"],
    "Fire" => ["https://fire.slc.gov", "https://www.slc.gov/fire/"],
    "Census" => ["https://www.slc.gov/census"]
  }

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
    super.except("created_at", "updated_at")
      .merge("s3_endpoint" => s3_endpoint)
  end

  def discover_documents!(document_data, collect = false)
    return if document_data.empty?
    collection = []

    # Process one document at a time to minimize memory footprint
    document_data.each_with_index do |data, index|
      url = data[:url]
      modification_date = data[:modification_date]

      # Find existing document - one query per document but minimal memory usage
      existing_document = documents.find_by(url: url)

      ActiveRecord::Base.transaction do
        if existing_document
          if existing_document.modification_date.to_i != modification_date.to_i
            existing_document.update!(
              attributes_from(data).reverse_merge(
                file_name: clean_string(data[:file_name]) || existing_document.file_name
              )
            )
            if collect
              # Update individual document
              collection << existing_document
            end
          end
        else
          begin
            file_name = clean_string(data[:file_name]) ||
              (url ? File.basename(URI.parse(url).path) : "unknown")
            if collect
              collection << documents.create!(attributes_from(data).reverse_merge(file_name: file_name))
            else
              documents.create!(attributes_from(data).reverse_merge(file_name: file_name))
            end
          rescue => e
            puts "Error creating document: #{e.message} for URL: #{url}"
          end
        end
      end
      # Force frequent garbage collection - every 5 documents
      if index % 5 == 0
        GC.start(full_mark: true, immediate_sweep: true)
        ActiveRecord::Base.connection_pool.release_connection
        unless collect
          puts "Memory usage: #{`ps -o rss= -p #{Process.pid}`.to_i / 1024} MB" if index % 100 == 0
        end
      end
      # Clear references to help GC
      data = nil
      existing_document = nil
    end
    if collect
      collection
    end
  end

  def process_csv_documents(csv_path)
    File.open(csv_path, "r") do |file|
      SmarterCSV.process(file, {chunk_size: 100}) do |chunk|
        documents = []
        skipped = 0
        chunk.each do |row|
          row = row.stringify_keys
          encoded_url = URI::DEFAULT_PARSER.escape(row["url"])

          # Parse file size (remove KB suffix and convert to float)
          file_size = row["file_size"]&.gsub("KB", "")&.strip&.to_f

          # Parse source from CSV - handle the ['url'] format
          source = if row["source"]
            # Extract URLs from the string
            urls = row["source"].scan(/'([^']+)'/).flatten
            urls.empty? ? nil : urls
          end

          complexity = if ((row["predicted_category"] != "Form") &&
            (row["number_of_tables"]&.to_i == 0) &&
            (row["number_of_images"]&.to_i == 0)) ? "Simple" : "Complex"
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
            number_of_pages: row["number_of_pages"]&.to_i,
            number_of_tables: row["number_of_tables"]&.to_i,
            number_of_images: row["number_of_images"]&.to_i,
            complexity: complexity
          }
        rescue URI::InvalidURIError => e
          puts "Skipping invalid URL: #{row["url"]}"
          puts "Error: #{e.message}"
          skipped += 1
        end

        discover_documents!(documents)
        documents = nil
        puts "Skipped #{skipped} documents due to invalid URLs" if skipped > 0
      end
    end
  end

  private

  def attributes_from(data)
    {
      document_category: data[:predicted_category] || data[:document_category],
      document_category_confidence: data[:predicted_category_confidence] || data[:document_category_confidence],
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
      number_of_tables: data[:number_of_tables],
      number_of_images: data[:number_of_images],
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
