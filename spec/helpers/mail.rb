module MailHelpers
  def wait_for_mail_delivery
    Timeout.timeout(5) do
      loop do
        break if ActionMailer::Base.deliveries.any?
        sleep(0.1)
      end
    end
  end
end

RSpec.configure do |config|
  config.include MailHelpers, type: :feature
end
