class Traveler < ApplicationRecord
  acts_as_tenant :company

  belongs_to :producer, class_name: "User"
  has_many :quotes, dependent: :nullify

  validates :first_name, :last_name, :email, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end
end
