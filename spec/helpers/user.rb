module AuthHelpers
  def login_user(user)
    visit "/users/sign_in"
    within("#new_user") do
      fill_in "Email", with: user.email
      fill_in "Password", with: user.password
    end
    click_button "Log in"
    sleep(1)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :feature
end
