require "rails_helper"

describe "admins can see admin pages", js: true, type: :feature do
  before :each do
    Site.create(location: "Colorado", name: "City and County of Denver", primary_url: "https://www.denver.gov")
    @current_user = User.create(email: "user@example.com", password: "password")
    login_user(@current_user)
  end

  def open_user_menu
    within("#header") do
      find("[data-action='click->dropdown#toggle']").click
    end
    find("div[data-dropdown-target='menu']", visible: true)
  rescue Capybara::ElementNotFound
    # Retry once - Stimulus controller may not be connected yet
    sleep 0.5
    within("#header") do
      find("[data-action='click->dropdown#toggle']").click
    end
    find("div[data-dropdown-target='menu']", visible: true)
  end

  it "admins can view AI configuration" do
    visit "/"
    menu = open_user_menu
    within(menu) do
      expect(page).to have_content "My Sites"
      expect(page).to have_no_content "AI Settings"
    end
    visit "/configuration/edit"
    expect(page).to have_current_path("/sites")
    expect(page).to have_content "You don't have permission to access that page."
    @current_user.is_site_admin = true
    @current_user.save
    visit "/"
    open_user_menu
    click_link("AI Settings")
    expect(page).to have_current_path("/configuration/edit")
    expect(page).to have_content "AI Configuration Settings"
  end

  describe "user admins can" do
    let!(:users) { create_list(:user, 50) }

    it "view user admin pages" do
      visit "/"
      menu = open_user_menu
      within(menu) do
        expect(page).to have_content "My Sites"
        expect(page).to have_no_content "Admin Users"
      end
      visit "/admin/users"
      expect(page).to have_current_path("/sites")
      expect(page).to have_content "You don't have permission to access that page."
      visit "/admin/users/new"
      expect(current_path).to eq("/sites")
      expect(page).to have_content "You don't have permission to access that page."
      visit "/admin/users/1/edit"
      expect(page).to have_current_path("/sites")
      expect(page).to have_content "You don't have permission to access that page."
      @current_user.is_user_admin = true
      @current_user.save
      visit "/admin/users"
      expect(page).to have_content "Manage Users"
      expect(page).to have_content(/user\d{2}@example\.com None \d{4}-\d{2}-\d{2} \d{2}:\d{2} Never No No Edit/, count: 25)
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
      expect(page).to have_content(/bob@example\.com City and County of Denver \d{4}-\d{2}-\d{2} \d{2}:\d{2} Never No Yes Edit/)
      within("#user-list tbody tr:nth-child(1)") do
        click_link("Edit")
      end
      expect(page).to have_content("Edit bob@example.com")
      select "None", from: "Site"
      check "Is site admin"
      click_button "Update"
      expect(page).to have_current_path("/admin/users")
      expect(page).to have_content(/bob@example\.com None \d{4}-\d{2}-\d{2} \d{2}:\d{2} Never Yes Yes Edit/)
      # Test pagination and search.
      visit "/admin/users"
      expect(page).to have_content "Manage Users"
      expect(page).to have_content(/(bob|user\d{2})@example\.com/, count: 25)
      within("#user-list #pager") do
        click_link("2")
      end
      expect(page).to have_content "Manage Users"
      expect(page).to have_current_path(/admin\/users\?page=2/)
      expect(page).to have_content(/user\d{1,2}@example\.com/, count: 25)
      visit "/admin/users?page=3"
      expect(page).to have_content "Manage Users"
      expect(page).to have_current_path(/admin\/users\?page=3/)
      expect(page).to have_content(/user\d{0,2}@example\.com/, count: 2)
      within("#user-list") do
        fill_in id: "email", with: "bob"
        click_button "Apply"
      end
      expect(page).to have_current_path(/admin\/users\?email=bob/)
      expect(page).to have_content(/bob@example\.com None \d{4}-\d{2}-\d{2} \d{2}:\d{2} Never Yes Yes Edit/)
      expect(page).to have_no_content(/user\d{1,2}@example\.com/)
    end

    it "invite users" do
      clear_emails
      @current_user.is_user_admin = true
      @current_user.save
      visit "/admin/users/new"
      fill_in "Email", with: "test-invite@example.com"
      check "Send invitation email"
      click_button "Save"
      expect(page).to have_content "User added successfully. Instructions were emailed to the user."
      expect(page).to have_current_path "/admin/users"
      wait_for_mail_delivery
      open_email("test-invite@example.com")
      expect(current_email).to have_content "Your account has been created, but requires activation. Please follow the link below to set a new password and log in."
    end

    it "re-invite users" do
      clear_emails
      @current_user.is_user_admin = true
      @current_user.save
      visit "/admin/users"
      within("#user-list tbody tr:nth-child(1)") do
        click_link("Edit")
      end
      click_button "Update"
      expect(page).to have_current_path "/admin/users"
      expect(page).to have_no_content "User updated successfully. Instructions were resent to the users's email."
      sleep(2)
      expect(ActionMailer::Base.deliveries).to be_empty
      visit "/admin/users"
      within("#user-list tbody tr:nth-child(1)") do
        click_link("Edit")
      end
      check "Resend invitation email"
      click_button "Update"
      expect(page).to have_current_path "/admin/users"
      expect(page).to have_content "User updated successfully. Instructions were resent to the users's email."
      wait_for_mail_delivery
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end
end
