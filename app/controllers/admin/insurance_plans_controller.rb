class Admin::InsurancePlansController < ApplicationController
  before_action :authenticate_super_admin!
  before_action :set_plan, only: [:edit, :update, :destroy]

  def index
    @plans = InsurancePlan.includes(:provider).order(:provider_id)
  end

  def new
    @plan = InsurancePlan.new
  end

  def create
    @plan = InsurancePlan.new(plan_params)
    if @plan.save
      redirect_to admin_insurance_plans_path, notice: "Plan creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plan.update(plan_params)
      redirect_to admin_insurance_plans_path, notice: "Plan actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @plan.destroy
    redirect_to admin_insurance_plans_path, notice: "Plan eliminado."
  end

  private

  def set_plan
    @plan = InsurancePlan.find(params[:id])
  end

  def plan_params
    params.require(:insurance_plan).permit(:provider_id, :name, :description, :status, coverage_details: {})
  end
end
