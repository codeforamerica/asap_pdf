require "rails_helper"

describe "documents function as expected", js: true, type: :feature do
  before :each do
    @current_user = User.create(email_address: "user@example.com", password: "password")
    login_user(@current_user)
  end

  it "documents belong to a site" do
    # Create our test setup
    site = Site.create(name: "City of Denver", location: "Colorado", primary_url: "https://denvergov.org", user_id: @current_user.id)
    Document.create(url: "http://denvergov.org/docs/example.pdf", file_name: "example.pdf", document_category: "Agenda", accessibility_recommendation: "Unknown", site_id: site.id)
    site = Site.create(name: "City of Boulder", location: "Colorado", primary_url: "https://bouldercolorado.gov", user_id: @current_user.id)
    Document.create(url: "https://bouldercolorado.gov/docs/rtd_contract.pdf", file_name: "rtd_contract.pdf", document_category: "Agreement", accessibility_recommendation: "Unknown", site_id: site.id)
    Document.create(url: "https://bouldercolorado.gov/docs/teahouse_rules.pdf", file_name: "teahouse_rules.pdf", document_category: "Notice", accessibility_recommendation: "Unknown", site_id: site.id)
    Document.create(url: "https://bouldercolorado.gov/docs/farmers_market_2023.pdf", file_name: "farmers_market_2023.pdf", document_category: "Notice", accessibility_recommendation: "Unknown", site_id: site.id)
    # Do some testing.

    visit "/"
    click_link("City of Denver")
    within("#document-list") do
      expect(page).to have_content "Colorado: City of Denver"
      expect(page).to have_no_content "No documents found"
      expect(page).to have_content "example.pdf\nAgenda\nUnknown\nNo notes"
      notes = find("[data-text-edit-field-value='notes']")
      notes.click
      textarea = notes.find("textarea")
      textarea.send_keys("Fee fi fo fum")
      textarea.send_keys(:enter)
    end
    within("#sidebar") do
      expect(page).to have_content "Backlog\n1"
      expect(page).to have_content "In Review\n0"
      expect(page).to have_content "Done\n0"
    end
  end
end
