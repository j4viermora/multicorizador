class QuoteSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :origin, :string
  attribute :destination, :string
  attribute :departure_date, :date
  attribute :return_date, :date
  attribute :travelers_count, :integer, default: 1
  attribute :trip_type, :string, default: "single"
  attribute :metadata

  validates :origin, :destination, :departure_date, presence: true
  validates :travelers_count, numericality: { greater_than: 0, less_than_or_equal_to: 10 }

  def initialize(attrs = {})
    super
    self.metadata ||= {}
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
end
