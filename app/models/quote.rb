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

  scope :active, -> { where.not(status: ["purchased", "cancelled"]) }

  accepts_nested_attributes_for :traveler

  after_update_commit :broadcast_status_update, if: :saved_change_to_status?

  def generate_public_token
    self.public_token = SecureRandom.urlsafe_base64(16)
  end

  def editable?
    !["purchased", "cancelled"].include?(status)
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
