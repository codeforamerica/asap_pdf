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

  it "does not duplicate documents with escaping permutations" do
    # Test single encoded spaces matching no encoding.
    create(:document, url: "https://www.slcdocs.com/Planning/Online%20Open%20Houses/2020/09_2020/Verizon%20Cellular%20Monopole%20Conditional%20Use/Narrative%20-%20SAL%20Pepper%20-%20PLNPCM2020-00716.pdf", site: site)
    # Test single encoded spaces matching single encoded spaces.
    create(:document, url: "https://www.slcdocs.com/Planning/Applications/best%20test.pdf", site: site)
    # Test double encoded spaces matching single encoding.
    create(:document, url: "https://www.slcdocs.com/Planning/Planning%2520Commission/2022/03.%2520March/00740StaffReport_Part2_Attachment%2520K.pdf", site: site)
    # Test no encoding matching single encoding.
    create(:document, url: "https://www.slcdocs.com/Planning/Applications/Alley Vacation.pdf", site: site)
    # Test single encoded spaces matching no encoding.
    create(:document, url: "https://www.slcdocs.com/Planning/Applications/zoop%20soup.pdf", site: site)
    expect(Document.count).to eq 5
    expect { Rake::Task["documents:import_documents"].invoke(site.id, "spec/fixtures/documents/url_escaping.csv", false) }.to change(Document, :count).by(0)
  end
end
