class Admin::ProvidersController < ApplicationController
  before_action :authenticate_super_admin!
  before_action :set_provider, only: [ :show, :edit, :update, :destroy, :toggle_active ]

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

  # Alterna la participación del proveedor en las cotizaciones.
  #
  # Escribe únicamente `status`, sin pasar por `provider_params`: compartir los
  # strong params con el formulario completo dejaría abierta la posibilidad de
  # que esta acción termine tocando `config`, donde viven las credenciales.
  # Alterna sobre el estado actual en lugar de recibir el destino como parámetro,
  # para que dos pestañas abiertas no puedan pisarse con el mismo valor.
  def toggle_active
    @provider.update!(status: @provider.active? ? "inactive" : "active")

    redirect_to admin_providers_path,
      notice: "#{@provider.name} quedó #{@provider.active? ? 'activo' : 'inactivo'}."
  end

  private

  def set_provider
    @provider = Provider.find(params[:id])
  end

  def provider_params
    params.require(:provider).permit(:name, :slug, :status, config: {})
  end
end
