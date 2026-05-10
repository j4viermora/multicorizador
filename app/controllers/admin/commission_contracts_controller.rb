class Admin::CommissionContractsController < ApplicationController
  before_action :authenticate_super_admin!
  before_action :set_contract, only: [:edit, :update, :destroy]

  def index
    @contracts = CommissionContract.includes(:provider, :producer).order(:provider_id)
  end

  def new
    @contract = CommissionContract.new
  end

  def create
    @contract = CommissionContract.new(contract_params)
    if @contract.save
      redirect_to admin_commission_contracts_path, notice: "Contrato creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @contract.update(contract_params)
      redirect_to admin_commission_contracts_path, notice: "Contrato actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @contract.destroy
    redirect_to admin_commission_contracts_path, notice: "Contrato eliminado."
  end

  private

  def set_contract
    @contract = CommissionContract.find(params[:id])
  end

  def contract_params
    params.require(:commission_contract).permit(:provider_id, :producer_id, :provider_commission_rate, :producer_share_rate, :valid_from, :valid_until)
  end
end
