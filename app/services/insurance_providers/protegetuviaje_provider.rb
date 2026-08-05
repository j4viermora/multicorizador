module InsuranceProviders
  # Protegetuviaje (b2b2c.protegetuviaje.com) — API "Centro de Aliados".
  #
  # A diferencia de los demás proveedores, #quote no cotiza y termina ahí: la
  # API separa "cotización" (POST /api/quotes/new, sin costo, válida un
  # tiempo) de "orden" (POST /api/orders/new/{serial}, ahí sí requiere todos
  # los datos del pasajero/facturación/emergencia y devuelve el payment_link
  # real). Por eso este proveedor declara supports_order_creation? = true e
  # implementa #create_order en vez de #purchase_url — ver BaseProvider.
  #
  # Autenticación por headers x-api-key / x-api-secret (no bearer token).
  #
  # Un detalle no documentado en el swagger pero confirmado a mano contra el
  # ambiente real: el {code} del path de /api/orders/new/{code} es en
  # realidad el campo "serial" (UUID) de la cotización, no su "code"
  # legible (ej. "QTAR203782238") — el nombre del path param en el swagger
  # engaña.
  class ProtegetuviajeProvider < BaseProvider
    def self.slug = "protegetuviaje"

    PRODUCT_TYPE_KEYWORDS = { "annual" => "Anual", "multi_trip" => "Puntual", "single" => "Puntual" }.freeze

    def quote(quote)
      response = post_quote(build_quote_payload(quote))
      handle_error_response!(response) unless response.success?

      body = response.body
      Array(body["plans"]).map do |plan|
        {
          external_quote_id: body["serial"],
          price_cents: (plan.dig("prices", "total", "amount_selected_coin").to_f * 100).round,
          currency: body.dig("selected_coin", "code") || "USD",
          plan_name: plan["name"],
          provider_name: "Protegetuviaje",
          ptv_quote_serial: body["serial"],
          ptv_quote_code: body["code"],
          ptv_plan_code: plan["code"]
        }
      end
    end

    def purchase_url(quote_result)
      raise NotImplementedError, "Protegetuviaje no arma el link con un GET — usar #create_order"
    end

    def supports_order_creation?
      true
    end

    # passengers: [{ name:, lastname:, birth_date:, document_type:, document_number: }]
    # billing: { name:, lastname:, document_type:, document_number:, address: }
    # emergency: { name:, lastname:, phone_number:, email: }
    # contact (send_to): { phone_number:, email: }
    def create_order(quote_result, passengers:, billing:, emergency:, contact:)
      quote_serial = quote_result.raw_response["ptv_quote_serial"]
      plan_code = quote_result.raw_response["ptv_plan_code"]
      raise ProviderError, "Protegetuviaje: falta ptv_quote_serial/ptv_plan_code en el resultado" if quote_serial.blank? || plan_code.blank?

      payload = {
        currency: quote_result.price_currency,
        plan: plan_code.to_i,
        passengers: passengers.map { |p| order_passenger(p) },
        send_to: { phone_number: contact[:phone_number], email: contact[:email] },
        billing: order_billing(billing),
        emergency: { name: emergency[:name], lastname: emergency[:lastname], phone_number: emergency[:phone_number], email: emergency[:email] }
      }

      response = http_client.post("api/orders/new/#{quote_serial}", payload) { |req| authenticate!(req) }
      handle_error_response!(response) unless response.success?

      order = response.body["order"] || {}
      {
        order_code: order["code"],
        order_serial: order["serial"],
        payment_link: order["payment_link"],
        pdf_url: order["pdf_url"],
        total: order["total"],
        currency: order["currency"]
      }
    end

    # Estado de una orden ya creada — usado por el sweep job que reemplaza al
    # webhook que esta API no ofrece. Normaliza el texto libre de PTV
    # ("Pago no realizado", "Pagada", "Emitida", "Cancelada"...) a un símbolo.
    def order_status(order_serial)
      response = http_client.get("api/orders/get/#{order_serial}") { |req| authenticate!(req) }
      handle_error_response!(response) unless response.success?

      data = response.body["data"] || {}
      status_text = data["status"].to_s

      {
        state: classify_status(status_text),
        raw_status: status_text,
        total: data.dig("price", "total"),
        currency: data.dig("price", "code"),
        pdf_url: data["pdf_url"],
        raw: data
      }
    end

    private

    def classify_status(text)
      return :paid if text.match?(/pagad|emitid|paid|issued/i)
      return :cancelled if text.match?(/cancelad|rechazad|cancel/i)
      :pending
    end

    def order_passenger(p)
      {
        name: p[:name],
        lastname: p[:lastname],
        birth_date: p[:birth_date],
        document_type: p[:document_type],
        document_number: p[:document_number]
      }
    end

    def order_billing(billing)
      {
        name: billing[:name],
        lastname: billing[:lastname],
        document_type: billing[:document_type],
        document_number: billing[:document_number],
        address: billing[:address]
      }
    end

    def post_quote(payload)
      http_client.post("api/quotes/new", payload) { |req| authenticate!(req) }
    end

    def authenticate!(request)
      request.headers["x-api-key"] = provider.config_for(:api_key)
      request.headers["x-api-secret"] = provider.config_for(:api_secret)
    end

    def handle_error_response!(response)
      message = response.body.is_a?(Hash) ? (response.body["message"] || response.body["error"]) : response.body.to_s
      message = message.is_a?(Hash) ? message.to_json : message.to_s
      raise ProviderError, "Protegetuviaje respondió #{response.status}: #{message.presence || 'sin detalle'}"
    end

    def build_quote_payload(quote)
      {
        date_from: quote.departure_date.to_s,
        date_to: (quote.return_date || quote.departure_date + 10.days).to_s,
        origin: resolve_origin_code(quote.origin),
        destinations: resolve_destination_codes(quote.destination),
        passengers: (quote.ages.presence || [ 30 ]).map(&:to_i),
        product_type: product_type_id_for(quote.trip_type).to_s,
        email: contact_email(quote),
        coin: Money.default_currency.iso_code
      }
    end

    def contact_email(quote)
      return quote.traveler.email if quote.respond_to?(:traveler) && quote.traveler&.email.present?
      quote.respond_to?(:producer) ? quote.producer&.email : nil
    end

    def resolve_origin_code(origin)
      country = find_country(origin)
      raise ProviderError, "Origen '#{origin}' sin código ISO reconocido por Protegetuviaje" unless country
      country.alpha2
    end

    # Nuestro buscador permite elegir un destino puntual ("España") o una
    # región entera ("Europa"): PTV no tiene el concepto de zona (a
    # diferencia de Omint), solo códigos de país sueltos, así que una región
    # se traduce a la lista completa de países ISO3166 de ese continente.
    def resolve_destination_codes(destination)
      country = find_country(destination)
      return [ country.alpha2 ] if country

      region = region_name_for(destination)
      codes = ISO3166::Country.all.select { |c| c.region == region }.map(&:alpha2)
      raise ProviderError, "Destino '#{destination}' sin mapeo a país o región de Protegetuviaje" if codes.empty?

      codes
    end

    def region_name_for(name)
      ApplicationHelper::REGION_TRANSLATIONS.key(name)
    end

    def find_country(name)
      return nil if name.blank?
      ISO3166::Country.find_country_by_translated_names(name)
    end

    def product_type_id_for(trip_type)
      keyword = PRODUCT_TYPE_KEYWORDS.fetch(trip_type, "Puntual")
      product_types.find { |pt| pt["name"].to_s.include?(keyword) }&.dig("id") ||
        raise(ProviderError, "Protegetuviaje: no encontré un product_type que contenga '#{keyword}'")
    end

    def product_types
      Rails.cache.fetch("protegetuviaje:product_types:#{provider.id}", expires_in: 6.hours) do
        response = http_client.get("api/quotes/data") { |req| authenticate!(req) }
        handle_error_response!(response) unless response.success?
        response.body["productTypes"] || []
      end
    end
  end
end
