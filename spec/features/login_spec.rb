require "rails_helper"

describe "the signin process", type: :feature do
  before :each do
    User.create(email_address: 'user@example.com', password: 'password')
  end

  it "signs me in" do
    visit '/login'
    within("#login-form") do
      fill_in 'Test', with: 'user@example.com'
      fill_in 'Email Address', with: 'user@example.com'
      fill_in 'Password', with: 'password'
    end
    click_button 'Login'
    expect(page).to have_content 'Success'
  end
end