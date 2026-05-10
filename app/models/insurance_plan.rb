class InsurancePlan < ApplicationRecord
  belongs_to :provider

  validates :name, presence: true

  scope :active, -> { where(status: "active") }
end
