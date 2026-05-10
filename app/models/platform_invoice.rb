class PlatformInvoice < ApplicationRecord
  belongs_to :provider

  monetize :total_commission_cents

  enum :status, { draft: "draft", pending: "pending", paid: "paid" }
end
