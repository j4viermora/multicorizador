class Policy < ApplicationRecord
  attribute :webhook_payload, :json

  acts_as_tenant :company

  belongs_to :quote_result

  monetize :premium_cents, :total_cents

  enum :status, { active: "active", cancelled: "cancelled", expired: "expired" }

  validates :sold_via, inclusion: { in: %w[direct producer] }

  scope :direct, -> { where(sold_via: "direct") }
  scope :producer_sold, -> { where(sold_via: "producer") }

  def self.ransackable_attributes(_auth_object = nil)
    %w[sold_via policy_number status]
  end

  def producer
    quote_result.quote.producer
  end
end
