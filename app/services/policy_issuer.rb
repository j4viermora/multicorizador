class PolicyIssuer
  def self.call(...) = new(...).call

  def initialize(quote_result:, policy_number:, premium:, total: nil, issued_at: Time.current,
                 starts_at: nil, ends_at: nil, sold_via: "direct", webhook_payload: {})
    @quote_result = quote_result
    @policy_number = policy_number
    @premium = premium
    @total = total || premium
    @issued_at = issued_at
    @starts_at = starts_at
    @ends_at = ends_at
    @sold_via = sold_via
    @webhook_payload = webhook_payload
  end

  def call
    existing = Policy.find_by(policy_number: @policy_number)
    return existing if existing

    policy = Policy.create!(
      quote_result: @quote_result,
      company: @quote_result.quote.company,
      policy_number: @policy_number,
      issued_at: @issued_at,
      starts_at: @starts_at,
      ends_at: @ends_at,
      premium: @premium,
      total: @total,
      sold_via: @sold_via,
      webhook_payload: @webhook_payload
    )

    @quote_result.quote.update!(status: "purchased")

    policy
  end
end
