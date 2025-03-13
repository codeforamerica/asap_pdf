require "rails_helper"

describe "sites function as expected", type: :feature do
  def login(user)
    visit "/login"
    within("#login-form") do
      fill_in "Email Address", with: user.email_address
      fill_in "Password", with: user.password
    end
    click_button "Login"
    expect(page).to have_content "My Sites"
  end

  before :each do
    @current_user = User.create(email_address: "user@example.com", password: "password")
    login(@current_user)
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
    end
  end

  it "cannot see someone else's site" do
    user = User.create(email_address: "somebodyelse@example.com", password: "password")
    site = Site.create(name: "Boulder", location: "Colorado", primary_url: "https://bouldercolorado.gov", user_id: user.id)
    visit "/sites/#{site.id}/documents"
    expect(page).to have_content "ActiveRecord::RecordNotFound in DocumentsController#index"
  end
end
