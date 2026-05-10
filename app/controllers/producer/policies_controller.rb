class Producer::PoliciesController < ApplicationController
  before_action :authenticate_active_producer!

  def index
    @policies = Policy.joins(quote_result: :quote)
                      .where(quotes: { producer_id: current_user.id })
                      .order(created_at: :desc)
  end

  def show
    @policy = Policy.joins(quote_result: :quote)
                    .where(quotes: { producer_id: current_user.id })
                    .find(params[:id])
  end
end
