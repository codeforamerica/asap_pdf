require "rails_helper"

describe "rake documents:import_documents", type: :rake do
  let(:site) { create(:site, primary_url: "https://www.city.org") }

  it "imports the documents" do
    expect { Rake::Task["documents:import_documents"].invoke(site.id, "spec/fixtures/documents/slc_fixtures/salt_lake_city.csv", true) }.to change(Document, :count).by(100)
    # Run a second round, to make sure we don't duplicate documents.
    Rake::Task["documents:import_documents"].reenable
    expect { Rake::Task["documents:import_documents"].invoke(site.id, "spec/fixtures/documents/slc_fixtures/salt_lake_city.csv", true) }.to change(Document, :count).by(0)
    test_doc = Document.where(url: "http://www.slcdocs.com/slcgreen/CPRG/Jurisdiction/EPA%20CPRG%20Communities%20Meeting%20-%20SLC%20Metro%20Area%20(4.24.2023%20Slides).pdf").first
    expect(test_doc).not_to be_nil
    expect(test_doc.site_id).to eq site.id
    expect(test_doc.number_of_pages).to eq 35
    expect(test_doc.number_of_images).to eq 29
    expect(test_doc.number_of_tables).to eq 0
    expect(test_doc.document_category).to eq "Slides"
    expect(test_doc.document_status).to eq "Active"
    expect(test_doc.creation_date.strftime("%Y-%m-%d")).to eq "2023-10-24"
    expect(test_doc.modification_date.strftime("%Y-%m-%d")).to eq "2023-10-24"
    expect(test_doc.file_size).to eq 2
    expect(test_doc.source).to eq %w[https://www.slc.gov/sustainability/climate-positive/sl-clear https://www.slc.gov/sustainability/climate-positive/sl-clear#top]
    expect(test_doc.pdf_version).to eq "PDF 1.6"
    expect(test_doc.producer).to eq "Adobe PDF Library 23.6.136"
    expect(test_doc.author).to eq "Tyler Poulson"
    Rake::Task["documents:import_documents"].reenable
    expect { Rake::Task["documents:import_documents"].invoke(site.id, "spec/fixtures/documents/slc_fixtures/salt_lake_city_update.csv", true) }.to change(Document, :count).by(0)
    test_doc.reload
    expect(test_doc.site_id).to eq site.id
    expect(test_doc.number_of_pages).to eq 35
    expect(test_doc.number_of_images).to eq 0
    expect(test_doc.number_of_tables).to eq 0
    expect(test_doc.document_category).to eq "Slides"
    expect(test_doc.document_status).to eq "Removed"
    expect(test_doc.creation_date.strftime("%Y-%m-%d")).to eq "2023-10-24"
    expect(test_doc.modification_date.strftime("%Y-%m-%d")).to eq "2025-10-31"
    expect(test_doc.last_crawl_date.strftime("%Y-%m-%d")).to eq "2025-09-24"
    expect(test_doc.source).to eq nil
    expect(test_doc.pdf_version).to eq "PDF 1.6"
    expect(test_doc.producer).to eq "Adobe PDF Library 23.6.136"
    expect(test_doc.author).to eq "Mallard J. Ducksman III"
  end
end
