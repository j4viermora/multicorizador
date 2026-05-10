class Policy < ApplicationRecord
  acts_as_tenant :company

  belongs_to :quote_result

  monetize :premium_cents, :total_cents,
           :provider_commission_cents, :platform_commission_cents,
           :producer_commission_cents

  enum :status, { active: "active", cancelled: "cancelled", expired: "expired" }
  enum :producer_commission_status, { pending: "pending", invoiced: "invoiced", paid: "paid" }

  scope :pending_commission, -> { where(producer_commission_status: "pending") }
  scope :paid_commission, -> { where(producer_commission_status: "paid") }

  def producer
    quote_result.quote.producer
  end
end
