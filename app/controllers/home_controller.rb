class HomeController < ApplicationController
  layout "public"

  def index
    if current_user.nil?
      @company = Company.find_by!(slug: Company::RUKA_DIRECT_SLUG)
      @producer = resolve_producer
      @providers = Provider.active
      @quote = Quote.new(travelers_count: 6, trip_type: "single")
      render "public/landing/show"
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

  private

  def resolve_producer
    if params[:ref].present?
      @company.users.producer.active.find_by(id: params[:ref]) || default_producer
    else
      default_producer
    end
  end

  def default_producer
    @company.users.where(role: :producer, status: :active).order(:created_at).first ||
      @company.users.where(role: :producer).order(:created_at).first
  end
end
