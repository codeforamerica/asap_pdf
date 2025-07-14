class Admin::UsersController < ApplicationController

  include Access

  before_action :ensure_user_user_admin

  before_action :set_user, only: [:new, :edit, :update]
  before_action :site_list, only: [:new, :create, :edit, :update]
  before_action :set_minimum_password_length, only: [:new, :edit, :update]

  def index
    @users = User.all
  end

  def new
    render '/admin/users/new'
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to admin_users_path, notice: 'User added successfully'
    else
      render :new, status: 422
    end
  end

  def edit
    render '/admin/users/edit'
  end

  def update
    if params[:user][:password].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
      success = @user.update_without_password(user_params)
    else
      if @user.id == current_user.id
        bypass_sign_in @user, scope: "user"
        success = @user.update_with_password(user_params)
      else
        success = @user.update(user_params)
      end
    end
    if success
      redirect_to admin_users_path, notice: 'User updated successfully'
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
    @user = params[:id].present? ? User.find(params[:id]) : User.new
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :is_site_admin, :is_user_admin, :site_id)
  end

  def set_minimum_password_length
    @minimum_password_length = User.password_length.min
  end

end