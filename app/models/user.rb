class User < ApplicationRecord
  acts_as_tenant :company

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :company, optional: true
  accepts_nested_attributes_for :company

  enum :role, { producer: 0, super_admin: 1 }
  enum :status, { pending: 0, active: 1, suspended: 2 }

  has_many :quotes, foreign_key: :producer_id, dependent: :nullify
  has_many :travelers, foreign_key: :producer_id, dependent: :nullify
  has_many :producer_invoices, foreign_key: :producer_id, dependent: :nullify

  scope :producers, -> { where(role: :producer) }
  scope :active_producers, -> { producers.where(status: :active) }
  scope :pending_producers, -> { producers.where(status: :pending) }

  validates :first_name, :last_name, presence: true, if: :producer?

  def full_name
    "#{first_name} #{last_name}".presence || email
  end

  def active_for_authentication?
    super && !suspended?
  end

  def inactive_message
    suspended? ? :suspended : super
  end
end
