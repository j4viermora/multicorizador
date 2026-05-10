class Admin::DashboardController < ApplicationController
  before_action :authenticate_super_admin!

  def index
    @pending_producers_count = User.pending_producers.count
    @total_providers = Provider.count
    @total_policies = 0 # Policy.count cuando exista
  end
end
