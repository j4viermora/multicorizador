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

    @search = QuoteSearch.new(search_params)

    if @search.valid?
      @results = QuoteSearchService.new(@search).call
      render :results
    else
      @providers = Provider.active
      @quote = Quote.new(search_params)
      render :show, status: :unprocessable_entity
    end
  end

  def purchase
    @company = Company.find_by!(slug: params[:slug])
    @producer = resolve_producer
    @plan = plan_params
    @search = search_context_params
  end

  def checkout
    @company = Company.find_by!(slug: params[:slug])
    @producer = resolve_producer
    @plan = plan_params
    @search = search_context_params
    @passengers = passenger_params
  end

  def thanks
    @company = Company.find_by!(slug: params[:slug])
    @quote = Quote.find_by!(public_token: params[:token])
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

  def search_params
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
      :coverage_json
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
