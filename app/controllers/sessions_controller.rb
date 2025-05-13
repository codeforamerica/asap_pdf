class SessionsController < AuthenticatedController
  layout "centered"
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    if (user = User.authenticate_by(params.permit(:email_address, :password)))
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Welcome back!"
    else
      #flash.now[:alert] = "Try another email address or password."
      @session = (@session || Session.new)
      @session.errors.add(:base, "Try another email address or password.")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    redirect_to login_path, notice: "You have been signed out."
  end
end
