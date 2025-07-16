# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  layout "centered"

  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    set_flash_message! :notice, :send_paranoid_instructions
    resource.email = nil
    redirect_back(fallback_location: new_password_path(resource_name))
  end

  def edit
    @is_invitation = params[:is_invitation] == "1"
    self.resource = resource_class.new
    set_minimum_password_length
    resource.reset_password_token = params[:reset_password_token]
  end

end
