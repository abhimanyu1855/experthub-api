# frozen_string_literal: true

class Rack::Attack
  # Disable rate limiting in test environment
  self.enabled = false if Rails.env.test?

  # Throttle all requests by IP (300 requests per 5 minutes)
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|

    req.ip
  end

  # Throttle login attempts by IP (20 requests per minute)
  throttle("login/ip", limit: 20, period: 1.minute) do |req|
    if req.path == "/login" && req.post?
      req.ip
    end
  end

  # Throttle signup attempts by IP (10 requests per minute)
  throttle("signup/ip", limit: 10, period: 1.minute) do |req|
    if req.path == "/signup" && req.post?
      req.ip
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |_env|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: "Rate limit exceeded. Try again later." }.to_json]
    ]
  end
end
