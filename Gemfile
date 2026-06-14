source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "tzinfo-data", platforms: %i[windows jruby]
gem "bootsnap", require: false

# === Authentication ===
gem "devise"
gem "devise-jwt"

# === Authorization ===
gem "pundit"

# === API ===
gem "rack-cors"
gem "blueprinter"
gem "oj" # Fast JSON

# === State Machine ===
gem "aasm"

# === Payments ===
gem "stripe"
gem "money-rails"

# === AI / Vector Search ===
gem "neighbor" # pgvector integration

# === Background Jobs ===
gem "solid_queue"

# === Cache (durable, for webhook idempotency + rate limiting) ===
gem "solid_cache"

# === Real-time (ActionCable) ===
gem "redis", ">= 4.0.1"

# === Monitoring ===
gem "sentry-ruby"
gem "sentry-rails"

# === Utilities ===
gem "dotenv-rails"
gem "rack-attack"
gem "faraday"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :test do
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
end
