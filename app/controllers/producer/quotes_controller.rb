class Producer::QuotesController < ApplicationController
  before_action :authenticate_active_producer!
  before_action :set_quote, only: [:show, :edit, :update, :destroy]

  def index
    @quotes = current_user.quotes.order(created_at: :desc)
  end

  def show
    @quote_results = @quote.quote_results.successful
  end

  def new
    @quote = current_user.quotes.build
    @quote.build_traveler
  end

  def create
    @quote = current_user.quotes.build(quote_params)

    if @quote.save
      QuoteJob.perform_later(@quote.id)
      redirect_to producer_quote_path(@quote), notice: "Cotización creada. Consultando proveedores..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @quote.update(quote_params)
      redirect_to producer_quote_path(@quote), notice: "Cotización actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @quote.deletable?
      @quote.destroy
      redirect_to producer_quotes_path, notice: "Cotización eliminada."
    else
      redirect_to producer_quotes_path, alert: "No se puede eliminar una cotización con póliza emitida."
    end
  end

  private

  def set_quote
    @quote = current_user.quotes.find(params[:id])
  end

  def quote_params
    params.require(:quote).permit(
      :origin, :destination, :departure_date, :return_date,
      :travelers_count, :trip_type, :traveler_id,
      metadata: {},
      traveler_attributes: [:id, :first_name, :last_name, :email, :phone, :document, :birth_date]
    )
  end
end
