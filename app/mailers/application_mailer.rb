class ApplicationMailer < Devise::Mailer
  default from: "Code for America <admin@ada.codeforamerica.ai>"

  layout "mailer"

  def new_account_instructions(record, token)
    @token = token
    @resource = record
    mail(to: @resource.email, subject: "Welcome! Set up your account", template_path: "users/mailer")
  end
end
