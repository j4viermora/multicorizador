class HomeController < ApplicationController
  layout "public"

  # La raíz es SIEMPRE la landing pública de venta directa: se entra sin sesión
  # y nunca redirige al login ni a un panel, aunque haya un usuario logueado.
  # Cada panel se alcanza por su propia ruta (/admin, /producer).
  def index
    @company = Company.find_by!(slug: Company::RUKA_DIRECT_SLUG)
    @producer = resolve_producer
    @providers = Provider.active.with_attached_logo
    @testimonials = Testimonial.published.ordered
    @footer_links = FooterLink.published.ordered
    @quote = Quote.new(trip_type: "single")

    render "public/landing/show"
  end

  private

  def resolve_producer
    if params[:ref].present?
      @company.users.producer.active.find_by(id: params[:ref]) || default_producer
    else
      default_producer
    end
  end

  def default_producer
    @company.users.where(role: :producer, status: :active).order(:created_at).first ||
      @company.users.where(role: :producer).order(:created_at).first
  end
end
