class CommissionContract < ApplicationRecord
  belongs_to :provider
  belongs_to :producer, class_name: "User", optional: true

  validates :provider_commission_rate, :producer_share_rate,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :valid_from, presence: true

  scope :active, -> {
    where("valid_from <= ? AND (valid_until IS NULL OR valid_until >= ?)", Date.today, Date.today)
  }

  scope :active_for, ->(provider, producer) {
    active.where(provider: provider)
          .where(producer: producer)
          .or(active.where(provider: provider, producer: nil))
          .order(producer_id: :desc)
  }

  def self.resolve(provider, producer)
    active_for(provider, producer).first
  end
end
