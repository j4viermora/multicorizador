class Admin::TestimonialsController < ApplicationController
  before_action :authenticate_super_admin!
  before_action :set_testimonial, only: [ :edit, :update, :destroy, :toggle_published ]

  def new
    @testimonial = Testimonial.new(rating: 5, published: true)
  end

  def create
    @testimonial = Testimonial.new(testimonial_params)
    if @testimonial.save
      redirect_to admin_landing_path, notice: "Reseña creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @testimonial.update(testimonial_params)
      redirect_to admin_landing_path, notice: "Reseña actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @testimonial.destroy
    redirect_to admin_landing_path, notice: "Reseña eliminada."
  end

  # Publica o despublica sin abrir el formulario. Alterna sobre el estado
  # actual en lugar de recibir el destino, para que dos pestañas abiertas no
  # se pisen con el mismo valor.
  def toggle_published
    @testimonial.update!(published: !@testimonial.published?)

    redirect_to admin_landing_path,
      notice: "La reseña quedó #{@testimonial.published? ? 'publicada' : 'oculta'}."
  end

  private

  def set_testimonial
    @testimonial = Testimonial.find(params[:id])
  end

  def testimonial_params
    params.require(:testimonial)
          .permit(:author_name, :location, :source, :source_url, :rating, :body, :position, :published)
  end
end
