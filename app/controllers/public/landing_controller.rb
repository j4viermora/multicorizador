class Public::LandingController < ActionController::Base
  layout "public"

  def show
    @company = Company.find_by!(slug: params[:slug])
    @producer = resolve_producer
    @providers = Provider.active
    @quote = Quote.new(travelers_count: 1, trip_type: "single")
  end

  def create
    @company = Company.find_by!(slug: params[:slug])
    @producer = resolve_producer

    ActsAsTenant.with_tenant(@company) do
      @quote = @producer.quotes.build(quote_params.merge(status: "draft", created_by: "client"))
      QuoteJob.perform_later(@quote.id) if @quote.save
    end

    if @quote.persisted?
      redirect_to public_landing_results_path(@company.slug, @quote.public_token, ref: params[:ref])
    else
      @providers = Provider.active
      render :show, status: :unprocessable_entity
    end
  end

  def results
    @company = Company.find_by!(slug: params[:slug])
    @quote = ActsAsTenant.with_tenant(@company) { Quote.find_by!(public_token: params[:token]) }
  end

  def purchase
    @company = Company.find_by!(slug: params[:slug])
    @producer = resolve_producer
    @plan = plan_params
    @search = search_context_params
    @quote_token = params[:quote_token]
  end

  def checkout
    @company = Company.find_by!(slug: params[:slug])
    @producer = resolve_producer
    @plan = plan_params
    @search = search_context_params
    @passengers = passenger_params
    @quote_token = params[:quote_token]
    @quote = find_quote

    complete_purchase!(@quote, @plan, @passengers) if @quote
  end

  private

  def complete_purchase!(quote, plan, passengers)
    ActsAsTenant.with_tenant(@company) do
      primary = passengers.first || {}
      contact = contact_params

      traveler = Traveler.create!(
        producer: quote.producer,
        first_name: primary[:first_name].presence || "Pasajero",
        last_name: primary[:last_name].presence || "1",
        email: contact[:email].presence || quote.metadata["email"],
        phone: contact[:phone],
        document: primary[:document],
        birth_date: primary[:birth_date]
      )

      quote.update!(
        traveler: traveler,
        metadata: quote.metadata.merge(
          "passengers" => passengers,
          "contact_email" => contact[:email],
          "contact_phone" => contact[:phone],
          "emergency_contact" => emergency_params.to_h
        )
      )

      quote_result = quote.quote_results.find(plan[:quote_result_id])

      PolicyIssuer.call(
        quote_result: quote_result,
        policy_number: "RK-#{SecureRandom.hex(6).upcase}",
        issued_at: Time.current,
        starts_at: quote.departure_date,
        ends_at: quote.return_date,
        premium: quote_result.price,
        total: quote_result.price,
        sold_via: "direct"
      )
    end
  end

  def find_quote
    return nil if params[:quote_token].blank?

    ActsAsTenant.with_tenant(@company) { Quote.find_by(public_token: params[:quote_token]) }
  end

  def contact_params
    params.fetch(:contact, {}).permit(:email, :phone)
  end

  def emergency_params
    params.fetch(:emergency, {}).permit(:name, :phone)
  end

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

  def quote_params
    qp = params.require(:quote).permit(
      :origin, :destination, :departure_date, :return_date,
      :travelers_count, :trip_type, metadata: [ :email, :phone, ages: [] ]
    )
    qp[:metadata] = qp[:metadata]&.to_h || {}
    qp
  end

  def plan_params
    pp = params.require(:plan).permit(
      :provider_name, :provider_slug, :plan_name,
      :price_cents, :currency, :price_per_person_cents,
      :coverage_json, :quote_result_id
    ).to_h.with_indifferent_access
    pp[:coverage] = JSON.parse(pp.delete(:coverage_json) || "[]") rescue []
    pp
  end

  def search_context_params
    params.require(:search).permit(
      :origin, :destination, :departure_date, :return_date,
      :travelers_count, :trip_type, :email, :phone
    ).to_h.with_indifferent_access
  end

  def passenger_params
    params.require(:passengers).map do |p|
      p.permit(:first_name, :last_name, :document, :birth_date).to_h
    end
  end
end
