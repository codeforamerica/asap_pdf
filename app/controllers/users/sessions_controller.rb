# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  layout "centered"

  def new
    flash.clear
    super
  end

  def create
    self.resource = warden.authenticate(auth_options)
    if resource
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      self.resource = resource_class.new(sign_in_params)
      resource.errors.add(:base, "Invalid email or password")
      respond_with resource
    end
  end

  def destroy
    (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    # set_flash_message! :notice, :signed_out if signed_out
    yield if block_given?
    respond_to_on_destroy
  end
end
