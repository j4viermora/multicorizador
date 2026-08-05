module TripMetadata
  extend ActiveSupport::Concern

  included do
    before_validation :compact_ages_metadata
    validate :requires_at_least_one_age
  end

  def ages
    metadata["ages"] || metadata[:ages] || []
  end

  def trip_days
    return 7 unless return_date && departure_date
    (return_date - departure_date).to_i.clamp(1, 365)
  end

  def max_age
    ages.map(&:to_i).max || 30
  end

  private

  def compact_ages_metadata
    return unless metadata.is_a?(Hash)

    raw = metadata["ages"] || metadata[:ages]
    return unless raw.is_a?(Array)

    filled = raw.map { |age| age.to_s.strip }.reject(&:blank?)
    metadata["ages"] = filled
    self.travelers_count = filled.size if filled.any?
  end

  def requires_at_least_one_age
    filled = Array(metadata["ages"]).map { |age| age.to_s.strip }.reject(&:blank?)
    return if filled.any?

    errors.add(:base, "Indicá al menos una edad de pasajero")
  end
end
