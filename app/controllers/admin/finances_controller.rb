class Admin::FinancesController < ApplicationController
  before_action :authenticate_super_admin!

  def index
    @total_policies = Policy.count
    @total_provider_commission = Policy.sum(:provider_commission_cents)
    @total_platform_commission = Policy.sum(:platform_commission_cents)
    @total_producer_commission_pending = Policy.pending_commission.sum(:producer_commission_cents)
    @total_producer_commission_paid = Policy.paid_commission.sum(:producer_commission_cents)
    @recent_policies = Policy.order(created_at: :desc).limit(10)
  end
end
