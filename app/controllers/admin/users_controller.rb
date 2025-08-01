class Admin::UsersController < ApplicationController
  include Access

  before_action :ensure_user_is_user_admin

  before_action :set_user, only: [:edit, :update]
  before_action :site_list, only: [:new, :create, :edit, :update]
  before_action :set_minimum_password_length, only: [:new, :edit, :update]

  def index
    @users = User.all
  end

  def new
    @user = User.new
    render :new
  end

  def create
    @user = User.new(user_params)
    if @user.is_invited?
      temp_password = SecureRandom.hex(12)
      @user.password = temp_password
      @user.password_confirmation = temp_password
    end
    if @user.save
      begin
        msg = "User added successfully"
        if @user.send_new_account_instructions?
          msg = "User added successfully. Instructions were emailed to the user."
        end
        redirect_to admin_users_path, notice: msg
      rescue Net::SMTPFatalError => e
        redirect_to admin_users_path, alert: e.message
      end
    else
      render :new, status: 422
    end
  end

  def edit
    render :edit
  end

  def update
    if params[:user][:password].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
      params[:user].delete(:current_password)
      success = @user.update_without_password(user_params)
    elsif @user.id == current_user.id
      success = @user.update_with_password(user_params)
      bypass_sign_in @user, scope: "user"
    else
      success = @user.update(user_params)
    end
    if success
      redirect_to admin_users_path, notice: "User updated successfully"
    else
      render :edit, status: 422
    end
  end

  private

  def site_list
    @sites = Site.all.order(:location, :name).group_by(&:location).map do |location, sites|
      [location, sites.map { |site| [site.name, site.id] }]
    end
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :is_site_admin, :is_user_admin, :site_id, :is_invited)
  end

  def set_minimum_password_length
    @minimum_password_length = User.password_length.min
  end
end
