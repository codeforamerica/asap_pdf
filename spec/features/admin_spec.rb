require "rails_helper"

describe "admins can see admin pages", js: true, type: :feature do
  before :each do
    Site.create(location: "Colorado", name: "City and County of Denver", primary_url: "https://www.denver.gov")
    @current_user = User.create(email: "user@example.com", password: "password")
    login_user(@current_user)
  end

  it "admins can view AI configuration" do
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
    @current_user.is_site_admin = true
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

  it "admins can view user admin pages" do
    visit "/"
    within("#header") do
      user_menu = find("[data-action='click->dropdown#toggle']")
      user_menu.click
    end
    within("div[data-dropdown-target='menu']") do
      expect(page).to have_content "My Sites"
      expect(page).to have_no_content "Admin Users"
    end
    visit "/admin/users"
    expect(current_path).to eq("/sites")
    expect(page).to have_content "You don't have permission to access that page."
    visit "/admin/users/new"
    expect(current_path).to eq("/sites")
    expect(page).to have_content "You don't have permission to access that page."
    visit "/admin/users/1/edit"
    expect(current_path).to eq("/sites")
    expect(page).to have_content "You don't have permission to access that page."
    @current_user.is_user_admin = true
    @current_user.save
    visit "/admin/users"
    expect(page).to have_content "Manage Users"
    expect(page).to have_content "user@example.com None No Yes Edit"
    within("#user-list") do
      click_link "Add User"
    end
    expect(page).to have_current_path("/admin/users/new")
    fill_in "Email", with: "user@example.com"
    fill_in "Password", with: "123459!"
    fill_in "Password confirmation", with: "123459!"
    click_button "Save"
    expect(page).to have_current_path("/admin/users/new")
    expect(page).to have_content "Email has already been taken"
    fill_in "Email", with: "bob@example.com"
    fill_in "Password", with: "123459!"
    fill_in "Password confirmation", with: "123459!"
    check "Is user admin"
    select "City and County of Denver", from: "Site"
    click_button "Save"
    expect(page).to have_current_path("/admin/users")
    expect(page).to have_content "bob@example.com City and County of Denver No Yes Edit"
    within("#user-list tr:nth-child(2)") do
      click_link("Edit")
    end
    expect(page).to have_content("Edit bob@example.com")
    select "None", from: "Site"
    check "Is site admin"
    click_button "Update"
    expect(page).to have_current_path("/admin/users")
    expect(page).to have_content "bob@example.com None Yes Yes Edit"
  end
end
