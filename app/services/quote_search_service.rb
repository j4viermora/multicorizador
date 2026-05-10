class QuoteSearchService
  def initialize(search, providers: Provider.active)
    @search = search
    @providers = providers
  end

  def call
    results = []

    @providers.each do |provider|
      client = InsuranceProviders.for(provider)
      next unless client

      begin
        data = client.quote(@search)
        results << data.merge(
          provider_slug: provider.slug,
          status: "success"
        )
      rescue => e
        Rails.logger.error("[QuoteSearch] #{provider.slug} error: #{e.message}")
        results << {
          provider_name: provider.name,
          provider_slug: provider.slug,
          status: "error",
          error: e.message
        }
      end
    end

    results.select { |r| r[:status] == "success" }.sort_by { |r| r[:price_cents] }
  end
end
