class Company < ApplicationRecord
  has_many :users, dependent: :destroy

  SUPPORTED_CURRENCIES = Money::Currency.all.map(&:iso_code).sort.freeze

  validates :name, presence: true
  validates :currency, presence: true, inclusion: { in: SUPPORTED_CURRENCIES }
  validates :slug, uniqueness: true, allow_nil: true,
            format: { with: /\A[a-z0-9\-]+\z/, message: "solo puede contener letras minúsculas, números y guiones" }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  def public_url_path
    "/cotizar/#{slug}" if slug.present?
  end

  private

  def generate_slug
    base = name.parameterize
    candidate = base
    counter = 2
    while Company.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{counter}"
      counter += 1
    end
    self.slug = candidate
  end
end
