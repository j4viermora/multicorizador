require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Some hosting providers (e.g. Dokploy) inject a DATABASE_URL with a
# "mariadb://" scheme when linking a MariaDB service. Rails auto-merges that
# URL into the primary db config and resolves the adapter from its scheme, so
# without this alias it looks for a nonexistent "mariadb" adapter instead of
# reusing the mysql2 one (which works fine against MariaDB).
ActiveRecord::ConnectionAdapters.register(
  "mariadb", "ActiveRecord::ConnectionAdapters::Mysql2Adapter", "active_record/connection_adapters/mysql2_adapter"
)

module Ruka
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.i18n.default_locale = :es
    config.i18n.available_locales = [ :es, :en ]

    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
