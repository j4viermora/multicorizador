class InsurancePlan < ApplicationRecord
  attribute :coverage_details, :json

  belongs_to :provider

  validates :name, presence: true

  scope :active, -> { where(status: "active") }
end
