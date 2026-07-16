module TripMetadata
  extend ActiveSupport::Concern

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
end
