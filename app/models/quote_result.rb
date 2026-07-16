class QuoteResult < ApplicationRecord
  acts_as_tenant :company

  belongs_to :quote
  belongs_to :provider
  belongs_to :insurance_plan, optional: true
  has_one :policy, dependent: :nullify

  monetize :price_cents

  enum :status, { pending: "pending", success: "success", error: "error" }

  scope :successful, -> { where(status: "success") }
end
