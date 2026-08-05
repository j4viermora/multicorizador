# Enlace de la columna "Cotizá" del pie de la landing pública.
#
# Global (no multi-tenant), igual que Testimonial: lo carga el super admin.
class FooterLink < ApplicationRecord
  validates :label, :url, presence: true

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :label) }
end
