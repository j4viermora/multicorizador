class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  set_current_tenant_through_filter
  before_action :set_current_tenant

  private

  def set_current_tenant
    return unless current_user

    if current_user.super_admin?
      ActsAsTenant.current_tenant = nil
      Money.default_currency = Money::Currency.new("ARS")
    else
      ActsAsTenant.current_tenant = current_user.company
      Money.default_currency = Money::Currency.new(current_user.company.currency)
    end
  end

  def authenticate_super_admin!
    unless current_user
      redirect_to new_user_session_path, alert: "Debes iniciar sesión"
      return
    end

    unless current_user.super_admin?
      redirect_to root_path, alert: "No autorizado"
    end
  end

  def authenticate_active_producer!
    unless current_user
      redirect_to new_user_session_path, alert: "Debes iniciar sesión"
      return
    end

    unless current_user.producer? && current_user.active?
      redirect_to root_path, alert: "No autorizado"
    end
  end
end
