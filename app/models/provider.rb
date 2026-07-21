class Provider < ApplicationRecord
  # MariaDB reports JSON columns as longtext, so Rails would treat this as a
  # plain string and store `to_s` output. Declare the cast explicitly.
  attribute :config, :json

  has_many :insurance_plans, dependent: :destroy
  has_many :quote_results, dependent: :nullify

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def config_for(key)
    config.fetch(key.to_s, nil)
  end
end
