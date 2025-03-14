require "rails_helper"

describe "sites function as expected", js: true, type: :feature do
  before :each do
    @current_user = User.create(email_address: "user@example.com", password: "password")
    login_user(@current_user)
  end

  it "can create a site" do
    visit "/"
    click_button "Add Site", id: "add-site-modal"
    within("#add_site_modal") do
      expect(page).to have_content "Add New Site"
      fill_in "Name", with: "City of Denver"
      fill_in "Location", with: "Colorado"
      fill_in "URL", with: "https://www.denvergov.org"
      click_button "Add Site"
    end
    within("#sites-grid") do
      expect(page).to have_content "City of Denver"
      expect(page).to have_content "Colorado"
      expect(page).to have_content "https://www.denvergov.org"
      click_link "City of Denver"
    end
    within("#document-list") do
      expect(page).to have_content "Colorado: City of Denver"
      expect(page).to have_content "No documents found"
    end
    within("#sidebar") do
      expect(page).to have_content "Backlog\n0"
      expect(page).to have_content "In Review\n0"
      expect(page).to have_content "Done\n0"
      click_button "Filter Results"
      expect(page).to have_field(id: "start_date")
      expect(page).to have_field(id: "end_date")
      expect(page).to have_field(id: "filename")
      expect(page).to have_field(id: "category")
    end
  end

  it "cannot see someone else's site" do
    user = User.create(email_address: "somebodyelse@example.com", password: "password")
    site = Site.create(name: "Boulder", location: "Colorado", primary_url: "https://bouldercolorado.gov", user_id: user.id)
    visit "/sites/#{site.id}/documents"
    expect(page).to have_content "ActiveRecord::RecordNotFound in DocumentsController#index"
  end
end
