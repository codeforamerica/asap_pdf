module AuthHelpers
  def login_user(user)
    visit "/login"
    within("#login-form") do
      fill_in "Email Address", with: user.email_address
      fill_in "Password", with: user.password
    end
    click_button "Login"
    sleep(1)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :feature
end
