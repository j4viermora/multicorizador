class Admin::ProvidersController < ApplicationController
  before_action :authenticate_super_admin!
  before_action :set_provider, only: [:show, :edit, :update, :destroy]

  def index
    @providers = Provider.order(:name)
  end

  def show
  end

  def new
    @provider = Provider.new
  end

  def create
    @provider = Provider.new(provider_params)
    if @provider.save
      redirect_to admin_providers_path, notice: "Proveedor creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @provider.update(provider_params)
      redirect_to admin_providers_path, notice: "Proveedor actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @provider.destroy
    redirect_to admin_providers_path, notice: "Proveedor eliminado."
  end

  private

  def set_provider
    @provider = Provider.find(params[:id])
  end

  def provider_params
    params.require(:provider).permit(:name, :slug, :status, config: {})
  end
end
