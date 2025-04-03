require "zip"

namespace :documents do
  desc "Bootstrap"
  task bootstrap: :environment do
    admin = User.first

    # Create Salt Lake City site
    slc = Site.find_or_create_by!(
      name: "SLC.gov",
      location: "Salt Lake City, UT",
      primary_url: "https://www.slc.gov/",
      user: admin
    )
    puts "Created site: #{slc.name}"

    # Create San Rafael site
    san_rafael = Site.find_or_create_by!(
      name: "The City with a Mission",
      location: "San Rafael, CA",
      primary_url: "https://www.cityofsanrafael.org/",
      user: admin
    )
    puts "Created site: #{san_rafael.name}"

    # Create Austin site
    austin = Site.find_or_create_by!(
      name: "The Official Website of The City of Austin",
      location: "Austin, TX",
      primary_url: "https://www.austintexas.gov/",
      user: admin
    )
    puts "Created site: #{austin.name}"

    ga = Site.find_or_create_by!(
      name: "georgia.gov",
      location: "Georgia",
      primary_url: "https://georgia.gov/",
      user: admin
    )
    puts "Created site: #{ga.name}"

    csv_manifest = {
      "georgia.csv" => ga,
      "austin.csv" => austin,
      "san_rafael.csv" => san_rafael,
      "salt_lake_city.csv" => slc
    }

    Zip::File.open(Rails.root.join("db", "seeds", "site_documents.zip")) do |zipfile|
      zipfile.each do |entry|
        if entry.file?
          file_name = entry.name.delete_prefix("site_documents/")
          if csv_manifest.has_key?(file_name)
            site = csv_manifest[file_name]
            puts "\nProcessing #{site.name} documents..."
            site.process_csv_documents(entry.get_input_stream.read)
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
end
