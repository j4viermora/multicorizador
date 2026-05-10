class Producer::DashboardController < ApplicationController
  before_action :authenticate_active_producer!

  def index
    @quotes_count = current_user.quotes.count
    @travelers_count = current_user.travelers.count
  end
end
