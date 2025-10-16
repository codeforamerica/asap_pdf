class ApplicationMailer < Devise::Mailer
  layout "mailer"
  helper :application

  def new_account_instructions(record, token)
    @token = token
    @resource = record
    mail(to: @resource.email, subject: "Welcome to the Code for America PDF Accessibility App! Set up your account", template_path: "users/mailer")
  end
end
