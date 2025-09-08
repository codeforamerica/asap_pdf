require "zip"

namespace :documents do
  desc "Bootstrap"
  task bootstrap: :environment do |t, args|
    User.first
    # Create Salt Lake City site
    slc = Site.find_or_create_by!(
      name: "SLC.gov",
      location: "Salt Lake City, UT",
      primary_url: "https://www.slc.gov/"
    )
    puts "Created site: #{slc.name}"
    slc.process_archive_or_csv "db/seeds/site_documents_dev/salt_lake_city.csv", true
    # Create San Rafael site
    san_rafael = Site.find_or_create_by!(
      name: "The City with a Mission",
      location: "San Rafael, CA",
      primary_url: "https://www.cityofsanrafael.org/"
    )
    san_rafael.process_archive_or_csv "db/seeds/site_documents_dev/san_rafael.csv", true
  end

  desc "Import documents"
  task :import_documents, [:site_id, :file_path, :archive] => :environment do |t, args|
    args.with_defaults(archive: false)
    site = Site.find(args.site_id)
    site.process_archive_or_csv args.file_path, args.archive.to_s.strip.downcase == "true"
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
      match = false
      Site::DEPARTMENT_MAPPING.each do |department, urls|
        urls.each do |url|
          if document.url.include? url
            p "Assigning #{department} to #{document.url}\n"
            match = true
            document.department = department
            document.save!
          end
          unless match
            document.source.each do | source |
              if source.include? url
                p "Assigning #{department} to #{document.url} from source url #{source}\n"
                match = true
                document.department = department
                document.save!
              end
            end
          end
        end
        break if match
      end
      unless match
        p "Found no department for #{document.url}\n"
      end
    end
  end

  desc "Add PDF complexity."
  task add_pdf_complexity: :environment do
    PaperTrail.request(enabled: false) do
      Document.where(complexity: nil).find_each do |document|
        unless document.number_of_tables.nil? || document.number_of_images.nil?
          document.save
        end
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

  desc "Add document inference"
  task :add_document_inference, [:document_id, :inference_type, :inference_value, :inference_reason, :include_feedback] => :environment do |t, args|
    doc = Document.find(args.document_id)
    if doc.nil?
      raise ActiveRecord::RecordNotFound
    end
    inference = DocumentInference.new(
      inference_type: args.inference_type,
      inference_value: args.inference_value,
      inference_reason: args.inference_reason,
      document: doc
    )
    inference.save!
    if args.include_feedback.to_s.strip.downcase == "true"
      FeedbackItem.create!(document_inference: inference, sentiment: "negative", comment: "This is a negative comment.", user_id: 1)
    end
  end
end
