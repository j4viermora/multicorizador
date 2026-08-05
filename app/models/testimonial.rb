# Reseña de un cliente, mostrada en la landing pública.
#
# No es multi-tenant a propósito: igual que `Provider`, la carga el super admin
# desde /admin y vale para todas las landings.
class Testimonial < ApplicationRecord
  RATINGS = (1..5).to_a

  validates :author_name, :body, presence: true
  validates :rating, inclusion: { in: RATINGS }

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, created_at: :desc) }
end
