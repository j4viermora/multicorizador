class Provider < ApplicationRecord
  has_many :insurance_plans, dependent: :destroy
  has_many :commission_contracts, dependent: :destroy
  has_many :quote_results, dependent: :nullify

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  scope :active, -> { where(status: "active") }

  def config_for(key)
    config.fetch(key.to_s, nil)
  end
end
