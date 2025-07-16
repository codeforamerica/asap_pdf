class ApplicationMailer < Devise::Mailer
  default from: "admin@demo.codeforamerica.ai"
  layout "mailer"
end
