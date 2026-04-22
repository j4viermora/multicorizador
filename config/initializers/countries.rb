# frozen_string_literal: true

require "countries"

# Load additional data modules
ISO3166.configuration.enable_currency_extension!

# Use Spanish as the default locale for country names
ISO3166.configuration.locales = [ :es, :en ]
