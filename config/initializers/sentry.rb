# frozen_string_literal: true

# Sentry error monitoring — only active when SENTRY_DSN is set.
# Generate a DSN at https://sentry.io and add it to your production env.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.1).to_f
    config.environment = Rails.env
    config.enabled_environments = %w[production staging]
  end
end
