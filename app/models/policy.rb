class Policy < ApplicationRecord
  acts_as_tenant :company

  belongs_to :quote_result

  monetize :premium_cents, :total_cents

  enum :status, { active: "active", cancelled: "cancelled", expired: "expired" }

  def producer
    quote_result.quote.producer
  end
end
