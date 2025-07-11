class Users::AdminController < ApplicationController
  include Access
  def index
    @users = User.all
  end
end