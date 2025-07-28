require "rails_helper"

describe "users may log into the site", js: true, type: :feature do
  before :each do
    @current_user = User.create(email: "user@example.com", password: "password")
  end

  it "email and password are authenticated" do
    visit "/users/sign_in"
    expect(page).to have_selector "#new_user", wait: 5
    expect(page).to have_no_content "My Sites"
    assert_match "/users/sign_in", current_url
    within "#new_user" do
      # Test out validation.
      fill_in "Email", with: "user@example.com"
      fill_in "Password", with: "notagoodanswer"
      click_button "Log in"
      expect(page).to have_content "Invalid email or password", wait: 5
      expect(page).to have_selector "#user_email.input-error"
      expect(page).to have_selector "#user_password.input-error"
      assert_match "/users/sign_in", current_url
      # Test out success.
      fill_in "Email", with: "user@example.com"
      fill_in "Password", with: "password"
      click_button "Log in"
    end
    expect(page).to have_selector "#sites-grid", wait: 5
    expect(page).to have_content "Signed in successfully"
    expect(page).to have_no_selector "#new_user"
  end
  #clear_emails
  it "password resets" do
    clear_emails
    visit "/users/sign_in"
    click_link "Forgot your password?"
    expect(page).to have_current_path "/users/password/new", wait: 5
    expect(page).to have_content "Forgot your password?"
    fill_in "Email", with: "bob@example.com"
    click_button "Send instructions"
    expect(page).to have_content "If your email address exists in our database, you will receive a password recovery link at your email address in a few minutes."
    expect(ActionMailer::Base.deliveries).to be_empty
    fill_in "Email", with: "bob@example.com"
    click_button "Send instructions"
    expect(page).to have_content "If your email address exists in our database, you will receive a password recovery link at your email address in a few minutes."
  end
end
