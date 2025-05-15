require "rails_helper"

describe "users may log into the site", js: true, type: :feature do
  before :each do
    @current_user = User.create(email_address: "user@example.com", password: "password")
  end

  it "email and password are authenticated" do
    visit "/sites"
    expect(page).to have_selector "#login-form", wait: 5
    expect(page).to have_no_content "My Sites"
    assert_match "login", current_url
    within "#login-form" do
      # Test out validation.
      fill_in "Email Address", with: "user@example.com"
      fill_in "Password", with: "notagoodanswer"
      click_button "Login"
      expect(page).to have_content "Try another email address or password.", wait: 5
      expect(page).to have_selector "#email_address.input-error"
      expect(page).to have_selector "#password.input-error"
      assert_match "login", current_url
      # Test out success.
      fill_in "Email Address", with: "user@example.com"
      fill_in "Password", with: "password"
      click_button "Login"
    end
    expect(page).to have_selector "#sites-grid", wait: 5
    expect(page).to have_content "Welcome back!"
    expect(page).to have_no_selector "#login-form"
  end
end
