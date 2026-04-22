class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  set_current_tenant_through_filter
  before_action :set_current_tenant

  private

  def set_current_tenant
    return unless current_user

    set_current_tenant(current_user.company)
    Money.default_currency = Money::Currency.new(current_user.company.currency)
  end
end
