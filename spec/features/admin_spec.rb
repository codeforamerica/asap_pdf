require "rails_helper"

describe "admins can see admin pages", type: :feature do
  before :each do
    @current_user = User.create(email_address: "user@example.com", password: "password")
    login_user(@current_user)
  end

  it "admins can create and see sites" do
    visit "/"
    within("#header") do
      user_menu = find("[data-action='click->dropdown#toggle']")
      user_menu.click
    end
    within("div[data-dropdown-target='menu']") do
      expect(page).to have_content "My Sites"
      expect(page).to have_no_content "AI Settings"
    end
    visit "/configuration/edit"
    expect(current_path).to eq("/sites")
    expect(page).to have_content "You don't have permission to access that page."
    @current_user.is_admin = true
    @current_user.save
    visit "/"
    within("#header") do
      user_menu = find("[data-action='click->dropdown#toggle']")
      user_menu.click
      click_link("AI Settings")
    end
    expect(current_path).to eq("/configuration/edit")
    expect(page).to have_content "AI Configuration Settings"
  end
end
