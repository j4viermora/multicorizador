module InsuranceProviders
  # Omint Assistance — endpoint B2B CreateQuotationB2B.
  # A diferencia de los demás proveedores, una sola llamada devuelve varios
  # productos (OA 30, OA 50, OA 70...) en vez de un precio único — #quote
  # devuelve un Array de hashes normalizados (ver ProviderQuoteJob#perform,
  # que ya soporta Array.wrap para esto).
  #
  # Omint solo cotiza salidas desde Argentina y agrupa destinos en 9 zonas
  # fijas (ver DESTINATION_ZONES) — no acepta países sueltos. El origin/
  # destination del Quote llega como nombre de país o de región (elegido con
  # el autocomplete de países, no texto libre), así que lo resolvemos a esas
  # zonas vía el gem `countries` (ISO3166) en vez de un mapeo de texto plano.
  class OmintProvider < BaseProvider
    def self.slug = "omint"

    TARIFF_TYPE_CODE = "B"
    TRIP_TYPE_MAP = { "single" => "S", "multi_trip" => "S", "annual" => "A" }.freeze
    DEFAULT_ANNUAL_QUANTITY_OF_DAYS = 30

    # Zonas de destino de Omint mapeadas desde los nombres de región que ya
    # usa el autocomplete de la app (ApplicationHelper::REGION_TRANSLATIONS).
    # "América" no tiene equivalente único en Omint (se reparte en ARG/URU/
    # ASU/NAC/MAC), así que no aparece acá a propósito: para esa región
    # forzamos a resolver por país (ver #resolve_destination_code).
    REGION_TO_DESTINATION_CODE = {
      "Europa" => "EMO",
      "Asia" => "AAA",
      "África" => "AAA",
      "Oceanía" => "OCE"
    }.freeze

    def quote(quote)
      response = post_quotation(build_payload(quote))
      handle_error_response!(response) unless response.success?

      Array(response.body["products"]).map do |product|
        {
          external_quote_id: response.body["id"],
          price_cents: (product["grossPrice"].to_f * 100).round,
          currency: "ARS",
          plan_name: product["denomination"],
          provider_name: "Omint Assistance"
        }
      end
    end

    def purchase_url(quote_result)
      raise NotImplementedError, "Omint requiere el endpoint CreateComplete para emitir — no documentado todavía"
    end

    private

    def post_quotation(payload)
      do_post(payload, access_token)
    end

    # Reintenta UNA vez con un token nuevo si el primero da 401, tal como
    # pide el manual de Omint.
    def do_post(payload, token)
      response = http_client.post("/Quotation/CreateQuotationB2B", payload) do |req|
        req.headers["Authorization"] = "Bearer #{token}"
      end

      if response.status == 401
        Rails.cache.delete(token_cache_key)
        fresh_token = access_token
        return http_client.post("/Quotation/CreateQuotationB2B", payload) do |req|
          req.headers["Authorization"] = "Bearer #{fresh_token}"
        end
      end

      response
    end

    def handle_error_response!(response)
      case response.status
      when 401
        raise ProviderError, "Omint: token inválido tras reintento"
      else
        message = response.body.is_a?(Hash) ? Array(response.body["errors"]).join(", ") : response.body.to_s
        raise ProviderError, "Omint respondió #{response.status}: #{message.presence || 'sin detalle'}"
      end
    end

    def build_payload(quote)
      trip_type_code = TRIP_TYPE_MAP.fetch(quote.trip_type, "S")

      payload = {
        agreementNumber: provider.config_for(:agreement_number),
        productTypeCode: trip_type_code,
        tariffTypeCode: TARIFF_TYPE_CODE,
        departureCode: resolve_departure_code(quote.origin),
        destinationCode: resolve_destination_code(quote.destination),
        dateSince: quote.departure_date.to_time.iso8601,
        dateUntil: (quote.return_date || quote.departure_date + 10.days).to_time.iso8601,
        passengerAges: quote.ages.presence || [ 30 ],
        email: contact_email(quote)
      }
      payload[:quantityOfDays] = DEFAULT_ANNUAL_QUANTITY_OF_DAYS if trip_type_code == "A"
      payload.compact
    end

    def contact_email(quote)
      return quote.traveler.email if quote.respond_to?(:traveler) && quote.traveler&.email.present?
      quote.respond_to?(:producer) ? quote.producer&.email : nil
    end

    def resolve_departure_code(origin)
      country = find_country(origin)
      return "MAA" if country&.alpha2 == "AR"

      raise ProviderError, "Omint sólo cotiza salidas desde Argentina (origen recibido: '#{origin}')"
    end

    def resolve_destination_code(destination)
      zone = REGION_TO_DESTINATION_CODE[destination]
      return zone if zone

      country = find_country(destination)
      raise ProviderError, "Destino '#{destination}' sin mapeo a zona Omint" unless country

      destination_code_for_country(country) ||
        raise(ProviderError, "Destino '#{destination}' (#{country.alpha2}) sin zona Omint equivalente")
    end

    def destination_code_for_country(country)
      return "ARG" if country.alpha2 == "AR"
      return "URU" if country.alpha2 == "UY"

      case country.subregion
      when "Northern America" then "NAC"
      when "Central America", "Caribbean" then "MAC"
      when "South America" then "ASU"
      when "Western Asia" then "EMO"
      when "Australia and New Zealand", "Melanesia", "Micronesia", "Polynesia" then "OCE"
      else
        case country.region
        when "Europe" then "EMO"
        when "Asia", "Africa" then "AAA"
        when "Oceania" then "OCE"
        end
      end
    end

    def find_country(name)
      return nil if name.blank?
      ISO3166::Country.find_country_by_translated_names(name)
    end

    def access_token
      Rails.cache.fetch(token_cache_key, expires_in: 55.minutes) { fetch_new_token! }
    end

    def token_cache_key
      "omint:access_token:#{provider.id}"
    end

    def fetch_new_token!
      conn = Faraday.new(url: provider.config_for(:token_endpoint))
      response = conn.post do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(
          grant_type: "client_credentials",
          client_id: provider.config_for(:client_id),
          client_secret: provider.config_for(:client_secret),
          scope: provider.config_for(:scope)
        )
      end

      raise ProviderError, "Omint: no se pudo obtener token (#{response.status})" unless response.success?

      JSON.parse(response.body)["access_token"]
    end
  end
end
