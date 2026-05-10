class Producer::CommissionsController < ApplicationController
  before_action :authenticate_active_producer!

  def index
    @pending_policies = Policy.joins(quote_result: :quote)
                              .where(quotes: { producer_id: current_user.id })
                              .pending_commission
                              .order(created_at: :desc)

    @total_pending = @pending_policies.sum(:producer_commission_cents)
    @total_paid = Policy.joins(quote_result: :quote)
                        .where(quotes: { producer_id: current_user.id })
                        .paid_commission
                        .sum(:producer_commission_cents)
  end
end
