require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ExperthubApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
    config.middleware.use Rack::Attack

    # Active Record Encryption — all three keys MUST be set via environment variables in production.
    # Generate with: bin/rails db:encryption:init
    config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY") {
      raise "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY is not set" if Rails.env.production?
      "GOZaGaViUNnF8lXy5yKVniMPnj0EbB7Z"
    }
    config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY") {
      raise "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY is not set" if Rails.env.production?
      "vBtOYR9EZY7N8MXecPyda9TANv94xLZN"
    }
    config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT") {
      raise "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT is not set" if Rails.env.production?
      "G72Ut6H9Hx0kAN2VPIAXKdiVhVRM1M5f"
    }
  end
end
