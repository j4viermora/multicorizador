class HomeController < ApplicationController
  def index
    if current_user.nil?
      redirect_to new_user_session_path
    elsif current_user.super_admin?
      redirect_to admin_dashboard_path
    elsif current_user.producer? && current_user.active?
      redirect_to producer_dashboard_path
    else
      redirect_to new_user_session_path, alert: "Tu cuenta está pendiente de aprobación o suspendida."
    end
  end
end
