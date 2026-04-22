class Company < ApplicationRecord
  has_many :users, dependent: :destroy

  SUPPORTED_CURRENCIES = Money::Currency.all.map(&:iso_code).sort.freeze

  validates :name, presence: true
  validates :currency, presence: true, inclusion: { in: SUPPORTED_CURRENCIES }
end
