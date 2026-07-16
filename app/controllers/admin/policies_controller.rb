class Admin::PoliciesController < ApplicationController
  before_action :authenticate_super_admin!

  def index
    @q = Policy.includes(quote_result: [ :provider, { quote: :producer } ]).ransack(params[:q])
    @policies = @q.result.order(created_at: :desc)
  end

  def show
    @policy = Policy.find(params[:id])
  end
end
