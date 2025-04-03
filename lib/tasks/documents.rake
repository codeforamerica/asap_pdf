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

    # Process Georgia documents
    puts "\nProcessing Georgia documents..."
    ga.process_csv_documents(Rails.root.join("db", "seeds", "georgia.csv"))

    # Process Austin documents
    puts "\nProcessing Austin documents..."
    austin.process_csv_documents(Rails.root.join("db", "seeds", "austin.csv"))

    # Process San Rafael documents
    puts "\nProcessing San Rafael documents..."
    san_rafael.process_csv_documents(Rails.root.join("db", "seeds", "san_rafael.csv"))

    # Process Salt Lake City documents
    puts "\nProcessing Salt Lake City documents..."
    slc.process_csv_documents(Rails.root.join("db", "seeds", "salt_lake_city.csv"))
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
