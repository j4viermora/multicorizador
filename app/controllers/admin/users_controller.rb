class Admin::UsersController < ApplicationController
  before_action :authenticate_super_admin!
  before_action :set_user, only: [:show, :edit, :update]

  def index
    @users = User.producers.order(created_at: :desc)
  end

  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to admin_users_path, notice: "Productor actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:status, :first_name, :last_name, :phone)
  end
end
