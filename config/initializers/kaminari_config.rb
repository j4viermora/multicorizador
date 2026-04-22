# frozen_string_literal: true

Kaminari.configure do |config|
  config.default_per_page = 25
  config.max_per_page = 100
  config.window = 2
  config.param_name = :page
end
