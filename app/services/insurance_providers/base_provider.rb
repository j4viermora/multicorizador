module InsuranceProviders
  class BaseProvider
    class ProviderError < StandardError; end

    attr_reader :provider

    def initialize(provider)
      @provider = provider
    end

    def self.slug
      raise NotImplementedError
    end

    # Devuelve la cotización del proveedor para una búsqueda.
    #
    # Puede devolver un hash único o un array de hashes cuando el proveedor
    # ofrece varios niveles de plan para la misma búsqueda: ProviderQuoteJob
    # envuelve el retorno con Array.wrap y crea un QuoteResult por elemento.
    # Cada opción debe traer su propio external_quote_id y plan_name para ser
    # distinguible de las demás del mismo proveedor.
    def quote(quote)
      raise NotImplementedError
    end

    def purchase_url(quote_result)
      raise NotImplementedError
    end

    def parse_webhook(payload)
      raise NotImplementedError
    end

    def valid_webhook?(request)
      true
    end

    protected

    def http_client
      @http_client ||= Faraday.new(
        url: provider.config_for(:base_url),
        request: { timeout: provider.config_for(:timeout) || 30 }
      ) do |f|
        f.request :json
        f.response :json
      end
    end
  end
end
