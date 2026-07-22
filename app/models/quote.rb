class Quote < ApplicationRecord
  attribute :metadata, :json

  include TripMetadata

  acts_as_tenant :company

  belongs_to :producer, class_name: "User"
  belongs_to :traveler, optional: true
  has_many :quote_results, dependent: :destroy
  has_many :links, dependent: :destroy

  validates :origin, :destination, :departure_date, presence: true
  validates :travelers_count, numericality: { greater_than: 0 }
  validates :public_token, uniqueness: true, allow_nil: true

  before_create :generate_public_token, if: -> { public_token.blank? }

  enum :status, {
    draft: "draft",
    client_pending: "client_pending",
    quoting: "quoting",
    quoted: "quoted",
    no_results: "no_results",
    pending_payment: "pending_payment",
    purchased: "purchased",
    cancelled: "cancelled"
  }

  scope :active, -> { where.not(status: [ "purchased", "cancelled" ]) }

  # Una fila de la comparación: un proveedor con todas las opciones de plan que
  # cotizó, ya ordenadas de más económica a más cara.
  ProviderOffer = Struct.new(:provider, :options) do
    def cheapest_price_cents
      options.first.price_cents
    end
  end

  # Resultados exitosos agrupados en una fila por proveedor. Las opciones de cada
  # fila van de menor a mayor precio, y las filas se ordenan por su opción más
  # económica, de modo que el proveedor con la entrada más barata quede primero.
  def offers_by_provider
    quote_results.successful
                 .includes(:provider)
                 .group_by(&:provider)
                 .map { |provider, options| ProviderOffer.new(provider, options.sort_by(&:price_cents)) }
                 .sort_by(&:cheapest_price_cents)
  end

  # Proveedores que no pudieron cotizar. Se exponen aparte porque un resultado
  # fallido no tiene precio con el cual ordenarse, y su unidad de presentación es
  # el proveedor y no la opción.
  def failed_providers
    quote_results.where(status: "error").includes(:provider).map(&:provider).uniq
  end

  accepts_nested_attributes_for :traveler

  after_update_commit :broadcast_status_update, if: :saved_change_to_status?

  def generate_public_token
    self.public_token = SecureRandom.urlsafe_base64(16)
  end

  def editable?
    ![ "purchased", "cancelled" ].include?(status)
  end

  def deletable?
    status != "purchased"
  end

  def create_share_link!(expires_in: 7.days)
    links.create!(
      token: SecureRandom.urlsafe_base64(24),
      expires_at: expires_in.from_now,
      purpose: "quote_share"
    )
  end

  private

  def broadcast_status_update
    broadcast_replace_to(
      "quote_#{id}",
      target: "quote_status_#{id}",
      partial: "public/landing/quote_status",
      locals: { quote: self }
    )
  end
end
