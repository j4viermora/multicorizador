class WebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def create
    provider = Provider.find_by!(slug: params[:provider_slug])
    client = InsuranceProviders.for(provider)

    if client && client.valid_webhook?(request)
      WebhookProcessorJob.perform_later(provider.slug, request.request_parameters)
      head :accepted
    else
      head :unauthorized
    end
  end
end
