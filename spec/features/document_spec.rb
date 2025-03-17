require "rails_helper"

describe "documents function as expected", js: true, type: :feature do
  before :each do
    @current_user = User.create(email_address: "user@example.com", password: "password")
    login_user(@current_user)
  end

  it "documents belong to a site and may be manipulated" do
    # Create our test setup
    site = Site.create(name: "City of Denver", location: "Colorado", primary_url: "https://denvergov.org", user_id: @current_user.id)
    Document.create(url: "http://denvergov.org/docs/example.pdf", file_name: "example.pdf", document_category: "Agenda", accessibility_recommendation: "Unknown", site_id: site.id)
    site = Site.create(name: "City of Boulder", location: "Colorado", primary_url: "https://bouldercolorado.gov", user_id: @current_user.id)
    Document.create(url: "https://bouldercolorado.gov/docs/rtd_contract.pdf", file_name: "rtd_contract.pdf", document_category: "Agreement", accessibility_recommendation: "Unknown", site_id: site.id)
    Document.create(url: "https://bouldercolorado.gov/docs/teahouse_rules.pdf", file_name: "teahouse_rules.pdf", document_category: "Notice", accessibility_recommendation: "Unknown", site_id: site.id)
    Document.create(url: "https://bouldercolorado.gov/docs/farmers_market_2023.pdf", file_name: "farmers_market_2023.pdf", document_category: "Notice", accessibility_recommendation: "Unknown", site_id: site.id, modification_date: "2024-10-01")
    # Test single document and document editing.
    visit "/"
    click_link("City of Denver")
    within("#document-list") do
      expect(page).to have_content "Colorado: City of Denver"
      expect(page).to have_no_content "No documents found"
      expect(page).to have_content "example.pdf\nAgenda\nUnknown\nNo notes"
      expect(page).to have_no_content "rtd_contract.pdf"
      expect(page).not_to have_selector "[data-text-edit-field-value='notes'] textarea"
      notes = find("[data-text-edit-field-value='notes']")
      notes.click
      sleep(1)
      textarea = notes.find("textarea")
      textarea.send_keys("Fee fi fo fum")
      textarea.send_keys(:enter)
      expect(page).not_to have_selector "[data-dropdown-edit-field-value='accessibility_recommendation'] select"
      decision = find("[data-dropdown-edit-field-value='accessibility_recommendation']")
      decision.click
      select = decision.find("select")
      select.find("[value='Convert']").click
      workflow_button = find("[data-action='status#toggleMenu']")
      workflow_button.click
      click_link "Done"
    end
    visit "/"
    click_link("City of Denver")
    within("#document-list") do
      expect(page).to have_content "No documents found"
    end
    within("#sidebar") do
      click_link "Done"
    end
    within("#document-list") do
      expect(page).to have_no_content "No documents found"
      expect(page).to have_content "example.pdf\nAgenda\nConvert\nFee fi fo fum"
    end
    within("#sidebar") do
      expect(page).to have_content "Backlog\n0"
      expect(page).to have_content "In Review\n0"
      expect(page).to have_content "Done\n1"
    end
    # Test multiple documents and filtration.
    visit "/"
    click_link("City of Boulder")
    within("#document-list") do
      expect(page).to have_content "Colorado: City of Boulder"
      expect(page).to have_no_content "No documents found"
      expect(page).to have_css("tbody tr", count: 3)
    end
    within("#sidebar") do
      click_button "Filter Results"
      fill_in id: "start_date", with: "10/01/2024"
      fill_in id: "end_date", with: "10/31/2024"
      fill_in id: "filename", with: "farmers_market_2023.pdf"
      find("#category").find("[value='Notice']").click
      click_button "Apply Filters"
    end
    within("#document-list") do
      expect(page).to have_css("tbody tr", count: 1)
      expect(page).to have_content "farmers_market_2023.pdf"
      expect(page).to have_no_content "rtd_contract.pdf"
    end
    within("#sidebar") do
      click_button "Filter Results"
      click_link "Clear"
    end
    within("#document-list") do
      expect(page).to have_css("tbody tr", count: 3)
    end
  end

  it "documents have some tabs" do
    # Create our test setup
    site = Site.create(name: "City of Denver", location: "Colorado", primary_url: "https://denvergov.org", user_id: @current_user.id)
    Document.create(url: "http://denvergov.org/docs/example.pdf", file_name: "example.pdf", document_category: "Agenda", accessibility_recommendation: "Unknown", site_id: site.id)
    visit "/"
    click_link("City of Denver")
    # Test out the modal and tabs.
    within("#document-list") do
      find("tbody td:nth-child(1) button").click
    end
    within("#document-list .modal") do
      # Assess default tab.
      expect(page).to have_content "example.pdf"
      expect(page).to have_css("[data-action='modal#showSummaryView'].tab-active")
      expect(page).to have_content "Summarize Document"
      expect(page).to have_css("iframe[src='http://denvergov.org/docs/example.pdf#pagemode=none&toolbar=1']")
      # Check out "PDF Details" tab.
      click_button "PDF Details"
      expect(page).to have_no_css("[data-action='modal#showSummaryView'].tab-active")
      expect(page).to have_css("[data-action='modal#showMetadataView'].tab-active")
      expect(page).to have_no_css("iframe[src='http://denvergov.org/docs/example.pdf#pagemode=none&toolbar=1']")
      expect(page).to have_content "File Name\nexample.pdf"
      expect(page).to have_content "Type\nAgenda"
      expect(page).to have_content "Decision\nUnknown"
      # Add a note.
      notes = find("[data-controller='modal-notes'] textarea")
      notes.send_keys("Fee fi fo fum")
      click_button "Update Notes"
    end
    # Check out "History" tab and look for notes.
    visit "/"
    click_link("City of Denver")
    within("#document-list") do
      find("tbody td:nth-child(1) button").click
    end
    within("#document-list .modal") do
      click_button "History"
      expect(page).to have_content("Notes: blank → Fee fi fo fum")
      expect(page).to have_content("Document category: Other → Agenda")
    end
  end
end
