class HomeController < ApplicationController
  def index
    if current_user.nil?
      redirect_to public_landing_path(slug: Company::RUKA_DIRECT_SLUG)
    elsif current_user.super_admin?
      redirect_to admin_dashboard_path
    elsif current_user.producer? && current_user.active?
      redirect_to producer_dashboard_path
    elsif current_user.producer? && current_user.pending?
      redirect_to account_pending_path
    else
      sign_out current_user
      redirect_to new_user_session_path, alert: "Tu cuenta ha sido suspendida."
    end
  end
end
