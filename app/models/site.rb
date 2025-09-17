class Site < ApplicationRecord
  DEPARTMENT_MAPPING = {
    "Information management Services" => [
      "slc.gov/ims/",
      "slcdocs.com/ims"
    ],
    "Finance" => [
      "slc.gov/Finance",
      "slcdocs.com/finance"
    ],
    "City Attorney's Office" => [
      "slc.gov/attorney",
      "slcdocs.com/attorney"
    ],
    "Justice Courts" => [
      "slc.gov/courts",
      "slcdocs.com/courts"
    ],
    "Community and Neighborhoods (CAN)" => [
      "slc.gov/can",
      "slcdocs.com/can"
    ],
    "Building Services" => [
      "slc.gov/Buildingservices",
      "slcdocs.com/buildingservices"
    ],
    "Transportation" => [
      "slc.gov/transportation",
      "slcdocs.com/transportation"
    ],
    "Planning Division" => [
      "slc.gov/planningdivision",
      "slcdocs.com/planningdivision"
    ],
    "Public Services" => [
      "slc.gov/publicservices",
      "slcdocs.com/publicservices"
    ],
    "Public Lands Department" => [
      "slc.gov/parks",
      "slcdocs.com/parks"
    ],
    "MyStreet" => [
      "slc.gov/mystreet",
      "slcdocs.com/mystreet"
    ],
    "Sustainability" => [
      "slc.gov/sustainability",
      "slcdocs.com/slcgreen"
    ],
    "Department of Economic Development (EconDev)" => [
      "slc.gov/ed",
      "slcdocs.com/ed"
    ],
    "Public Utilities" => [
      "slc.gov/utilities",
      "slcdocs.com/utilities"
    ],
    "Human Resources" => [
      "slc.gov/hr",
      "slcdocs.com/hr"
    ],
    "Engineering" => [
      "slc.gov/engineering",
      "slcdocs.com/engineering"
    ],
    "Council District 1" => [
      "slc.gov/district1"
    ],
    "Council District 2" => [
      "slc.gov/district2"
    ],
    "Council District 3" => [
      "slc.gov/district3"
    ],
    "Council District 4" => [
      "slc.gov/district4"
    ],
    "Council District 5" => [
      "slc.gov/district5"
    ],
    "Council District 6" => [
      "slc.gov/district6"
    ],
    "Council District 7" => [
      "slc.gov/district7"
    ],
    "City Council Office" => [
      "slc.gov/council",
      "slcdocs.com/council"
    ],
    "Boards and Commissions" => [
      "slc.gov/boards",
      "slcdocs.com/boards"
    ],
    "Division of Youth and Family" => [
      "slc.gov/youthandfamily",
      "slcdocs.com/youthandfamily"
    ],
    "Emergency Management" => [
      "slc.gov/em",
      "slcdocs.com/em"
    ],
    "Historic Preservation" => [
      "slc.gov/histroic-preservation",
      "slcdocs.com/histroicpreservation"
    ],
    "Mayor's Office" => [
      "slc.gov/mayor",
      "slcdocs.com/mayor"
    ],
    "Mayor's Office of Access & Belonging" => [
      "slc.gov/access-belonging"
    ],
    "Housing Stability" => [
      "slc.gov/housingstability",
      "slcdocs.com/housingstability"
    ],
    "Homelessness" => [
      "slc.gov/homelessness",
      "slcdocs.com/homelessness"
    ]
  }

  has_many :documents, dependent: :destroy
  has_many :users

  validates :name, presence: true, uniqueness: true
  validates :location, presence: true
  validates :primary_url, presence: true, uniqueness: true
  validate :ensure_safe_url

  after_initialize :after_initialize

  def after_initialize
    @s3_manager = AwsS3Manager.new
  rescue
    @s3_manager = nil
  end

  def has_departments?
    documents.where.not(department: [nil, ""]).any?
  end

  def get_departments
    documents.pluck(:department).uniq.sort { |a, b|
      if a && b
        a <=> b
      else
        a ? 1 : -1
      end
    }.to_h { |a| [a.nil? ? "None" : a, a.nil? ? "None" : a] }
  end

  def has_complexities?
    documents.where.not(complexity: [nil, ""]).any?
  end

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

          # Parse file size (remove KB suffix and convert to float)
          file_size = row["file_size"]&.gsub("KB", "")&.strip&.to_f

          # Parse source from CSV - handle the ['url'] format
          source = if row["source"]
            # Extract URLs from the string
            urls = row["source"].scan(/'([^']+)'/).flatten
            urls.empty? ? nil : urls
          end

          documents << {
            url: row["url"],
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
            number_of_images: row["number_of_images"]&.to_i
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

  def process_archive_or_csv(file_path, is_archive)
    if is_archive
      archive_path = File.dirname(file_path) + ".zip"
      file_name = File.basename(file_path)
      Zip::File.open(archive_path) do |zipfile|
        match = false
        zipfile.each do |entry|
          if File.basename(entry.name) == file_name
            match = true
            puts "\nImporting documents from #{entry.name} in archive #{archive_path} into #{name}"
            tmp_path = "/tmp/#{file_name}"
            File.delete(tmp_path) if File.exist? tmp_path
            entry.extract(file_name, destination_directory: "/tmp/")
            process_csv_documents(tmp_path)
            File.delete(tmp_path) if File.exist? tmp_path
          end
        end
        unless match
          raise Errno::ENOENT, "File, #{file_path} not found inside archive #{archive_path}"
        end
      end
    else
      puts "\nImporting documents from #{file_path} into #{name}"
      process_csv_documents(file_path)
    end
  end

  def export_document_audit!(current_user)
    assert_s3_manager
    bucket_name = Rails.application.config.default_s3_bucket
    machine_site_name = name.downcase.gsub(/\W+/, "_")
    report_name = "audit_export_#{machine_site_name}_#{Time.now.strftime("%Y-%m-%dT%H-%M-%S")}"
    Tempfile.create([report_name, ".csv"]) do |temp_file|
      CSV.open(temp_file.path, "wb") do |csv|
        csv << Document.column_names
        documents.find_each do |record|
          csv << record.attributes.values
        end
      end
      metadata = {
        "created" => Time.now.iso8601,
        "author" => current_user.email
      }
      @s3_manager.write_file!(bucket_name, "/reports/#{machine_site_name}/#{report_name}.csv", temp_file.path, "text/csv", metadata)
    end
  end

  def get_document_audit_exports!
    assert_s3_manager
    bucket_name = Rails.application.config.default_s3_bucket
    machine_site_name = name.downcase.gsub(/\W+/, "_")
    {
      bucket_name: bucket_name,
      files: @s3_manager.get_files!(bucket_name, "/reports/#{machine_site_name}")
    }
  end

  def get_document_audit_link_hashes!
    assert_s3_manager
    export_links = []
    report_data = get_document_audit_exports!
    if report_data[:files].present?
      report_data[:files].each do |s3_object|
        metadata = @s3_manager.get_metadata!(report_data[:bucket_name], s3_object.key)
        export_links << {
          url: Rails.application.routes.url_helpers.workflow_audit_report_site_path(self, report_data[:bucket_name], s3_object.key),
          created: metadata.has_key?("created") ? metadata["created"] : "",
          author: metadata.has_key?("author") ? metadata["author"] : ""
        }
      end
    end
    export_links
  end

  private

  def assert_s3_manager
    if @s3_manager.nil?
      raise StandardError.new("Failed to connect to AWS environment (AwsS3Manager failed to initialize).")
    end
  end

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
