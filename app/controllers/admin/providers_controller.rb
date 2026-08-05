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
    assign_config!(@provider)
    if @provider.errors.empty? && @provider.save
      redirect_to admin_providers_path, notice: "Proveedor creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @provider.assign_attributes(provider_params)
    assign_config!(@provider)
    if @provider.errors.empty? && @provider.save
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
    params.require(:provider).permit(:name, :slug, :status, :logo)
  end

  # `config` llega del form como un textarea de JSON libre (ver
  # app/views/admin/providers/_form), es decir como un string escalar — no
  # como params anidados. `permit(config: {})` exige justo lo contrario (un
  # hash anidado) y descarta el valor en silencio si no lo recibe, así que el
  # proveedor se guardaba con `config` vacío sin ningún aviso. Se parsea acá
  # aparte y, si el JSON es inválido, se agrega el error para que el form se
  # vuelva a renderizar con el texto tal cual lo escribió el admin.
  def assign_config!(provider)
    raw = params.dig(:provider, :config)
    return if raw.blank?

    provider.config = JSON.parse(raw)
  rescue JSON::ParserError
    provider.errors.add(:config, "no es un JSON válido")
    # El form vuelve a mostrar esto en vez de @provider.config.to_json, para
    # que el admin corrija su typo en vez de perder todo lo que escribió.
    @config_input = raw
  end
end
