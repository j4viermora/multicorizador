class Admin::UsersController < ApplicationController
  before_action :authenticate_super_admin!
  before_action :set_user, only: [:show, :edit, :update, :approve]

  def index
    @users = User.producers.includes(:company).order(created_at: :desc)
  end

  def show
  end

  def edit
  end

  def approve
    @user.active!
    redirect_to admin_users_path, notice: "#{@user.full_name} fue aprobado."
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
    @user = User.includes(:company).find(params[:id])
  end

  def user_params
    params.require(:user).permit(:status, :first_name, :last_name, :phone,
                                 company_attributes: [:id, :name, :slug, :currency])
  end
end
