# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

app_domain = ENV.fetch("APP_DOMAIN", "experthub.localhost")

allowed_origins = [
  "http://localhost:5173",
  "http://localhost:5174",
  "http://localhost:3001",
  /\Ahttps?:\/\/.*\.localhost(:\d+)?\z/
]

# In production add the real wildcard subdomain and any explicit extra origins
if Rails.env.production?
  allowed_origins << /\Ahttps:\/\/.*\.#{Regexp.escape(app_domain)}\z/
  # e.g. CORS_EXTRA_ORIGINS=https://admin.experthub.app,https://experthub.app
  ENV.fetch("CORS_EXTRA_ORIGINS", "").split(",").each do |origin|
    allowed_origins << origin.strip unless origin.strip.empty?
  end
else
  allowed_origins << /\Ahttps?:\/\/.*\.#{Regexp.escape(app_domain)}(:\d+)?\z/
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization X-Tenant-Id],
      credentials: true,
      max_age: 600
  end
end
