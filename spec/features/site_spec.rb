require "rails_helper"

describe "sites function as expected", type: :feature do
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
    # @todo remove after adding site UI to user.
    @current_user.site = Site.last
    @current_user.save!
    visit "/"
    # end todo.
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
  end

  it "cannot see someone else's site" do
    site = Site.create(name: "Boulder", location: "Colorado", primary_url: "https://bouldercolorado.gov")
    User.create(email_address: "somebodyelse@example.com", password: "password", site: site)
    visit "/sites/#{site.id}/documents"
    expect(current_path).to eq("/sites")
    expect(page).to have_content("You don't have permission to access that site.")
  end
end
