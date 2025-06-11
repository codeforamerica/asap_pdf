require "zip"

namespace :documents do
  desc "Bootstrap"
  task :bootstrap, [:file_name] => :environment do |t, args|
    User.first

    # Create Salt Lake City site
    slc = Site.find_or_create_by!(
      name: "SLC.gov",
      location: "Salt Lake City, UT",
      primary_url: "https://www.slc.gov/"
    )
    puts "Created site: #{slc.name}"

    # Create San Rafael site
    san_rafael = Site.find_or_create_by!(
      name: "The City with a Mission",
      location: "San Rafael, CA",
      primary_url: "https://www.cityofsanrafael.org/"
    )
    puts "Created site: #{san_rafael.name}"

    # Create Austin site
    austin = Site.find_or_create_by!(
      name: "The Official Website of The City of Austin",
      location: "Austin, TX",
      primary_url: "https://www.austintexas.gov/"
    )
    puts "Created site: #{austin.name}"

    ga_dor = Site.find_or_create_by!(
      name: "Department of Revenue",
      location: "Georgia",
      primary_url: "https://dor.georgia.gov"
    )
    puts "Created site: #{ga_dor.name}"

    ga_dbf = Site.find_or_create_by!(
      name: "Department of Banking and Finance",
      location: "Georgia",
      primary_url: "https://dbf.georgia.gov"
    )
    puts "Created site: #{ga_dbf.name}"

    ga_psg = Site.find_or_create_by!(
      name: "Enterprise Policies, Standards and Guidelines (PSGs)",
      location: "Georgia",
      primary_url: "https://gta-psg.georgia.gov"
    )
    puts "Created site: #{ga_psg.name}"

    ga_dfcs = Site.find_or_create_by!(
      name: "Department of Human Services Division of Family & Children Services",
      location: "Georgia",
      primary_url: "https://dfcs.georgia.gov"
    )
    puts "Created site: #{ga_dfcs.name}"

    csv_manifest = {
      "dor_georgia.csv" => ga_dor,
      "dbf_georgia.csv" => ga_dbf,
      "gta_psg_georgia.csv" => ga_psg,
      "dfcs_georgia.csv" => ga_dfcs,
      "austin.csv" => austin,
      "san_rafael.csv" => san_rafael,
      "salt_lake_city.csv" => slc
    }

    archive_name = (Rails.env != "production") ? "site_documents_dev.zip" : "site_documents.zip"
    puts "Loading site data from #{archive_name}"

    Zip::File.open(Rails.root.join("db", "seeds", archive_name)) do |zipfile|
      zipfile.each do |entry|
        if entry.file?
          file_name = entry.name.delete_prefix("site_documents/").delete_prefix("site_documents_dev/")
          if csv_manifest.has_key?(file_name) && (args.file_name.nil? || (args.file_name == file_name))
            site = csv_manifest[file_name]
            puts "\nProcessing #{site.name} documents in #{entry.name}..."
            tmp_path = "/tmp/#{file_name}"
            File.delete(tmp_path) if File.exist? tmp_path
            entry.extract(tmp_path)
            site.process_csv_documents(tmp_path)
            File.delete(tmp_path) if File.exist? tmp_path
          end
        end
      end
    end
  end

  desc "Show percentage of null values for each column in the documents table"
  task null_percentages: :environment do
    documents_count = Document.count
    columns = Document.column_names

    puts "\nAnalyzing null values in documents table (#{documents_count} total records)\n\n"

    # Calculate max column name length for formatting
    max_length = columns.map(&:length).max

    # Print header
    header = "Column Name".ljust(max_length) + " | Total Records | Null Count | Null %"
    puts header
    puts "-" * header.length

    # Calculate and display stats for each column
    columns.each do |column|
      null_count = Document.where(column => nil).count
      percentage = documents_count.zero? ? 0 : (null_count.to_f / documents_count * 100).round(1)

      row = [
        column.ljust(max_length),
        documents_count.to_s.rjust(12),
        null_count.to_s.rjust(9),
        "#{percentage.to_s.rjust(5)}%"
      ].join(" | ")
      puts row
    end

    puts "\n"
  end

  desc "Update default decision type."
  task update_decision_type: :environment do
    Document.where(accessibility_recommendation: "Unknown").each do |document|
      document.accessibility_recommendation = Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION
      document.save
    end
  end

  desc "Update departments."
  task :update_department, [:site_id] => :environment do |t, args|
    Document.where(site_id: args.site_id).each do |document|
      Site::DEPARTMENT_MAPPING.each do |department, urls|
        urls.each { |url|
          if document.url.downcase.start_with?(url)
            document.department = department
            document.save
          end
        }
      end
    end
  end

  desc "Add PDF complexity."
  task add_pdf_complexity: :environment do
    Document.find_each do |document|
      unless document.number_of_tables.nil? || document.number_of_images.nil?
        complexity = ((document.document_category != "Form") &&
          (document.number_of_tables == 0) &&
          (document.number_of_images == 0)) ? Document::SIMPLE_STATUS : Document::COMPLEX_STATUS
        document.complexity = complexity
        document.save
      end
    end
  end

  desc "Validate creation and modification dates."
  task validate_dates: :environment do
    Document.where.not(creation_date: nil).find_each(batch_size: 50) do |document|
      if document.creation_date.year < 1995 || document.creation_date.year > Date.current.year
        document.creation_date = nil
        document.save
      end
    end
    Document.where.not(modification_date: nil).find_each(batch_size: 50) do |document|
      if document.modification_date.year < 1995 || document.modification_date.year > Date.current.year
        document.modification_date = nil
        document.save
      end
    end
  end
end
