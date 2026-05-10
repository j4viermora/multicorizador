class Public::QuotesController < ActionController::Base
  layout "public"

  def show
    @link = Link.active.find_by!(token: params[:token])
    @quote = @link.quote

    if @link.expired?
      @link.update!(status: "expired")
      render :expired, status: :gone and return
    end

    @link.record_access!
  end

  def update
    @link = Link.active.find_by!(token: params[:token])
    @quote = @link.quote

    if @quote.update(quote_params.merge(status: "quoting", created_by: "client"))
      QuoteJob.perform_later(@quote.id)
      redirect_to public_quote_path(@link.token), notice: "Cotización enviada. Pronto recibirás los resultados."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def quote_params
    params.require(:quote).permit(
      :origin, :destination, :departure_date, :return_date,
      :travelers_count, :trip_type, metadata: {},
      traveler_attributes: [:first_name, :last_name, :email, :phone, :document, :birth_date]
    )
  end
end
