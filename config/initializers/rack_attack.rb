# frozen_string_literal: true

# Rack::Attack — rate limiting and brute-force protection.
#
# Store: uses Rails.cache (wired to Redis in production via REDIS_URL).
# All throttle counters survive Puma restarts and are shared across workers.

class Rack::Attack
  # Disable in test environment so specs run at full speed.
  self.enabled = !Rails.env.test?

  # ── Throttle helpers ────────────────────────────────────────────────────────

  # Safe IP extraction: strips IPv6-mapped IPv4 (::ffff:1.2.3.4 → 1.2.3.4)
  # and falls back to REMOTE_ADDR so we never get nil as a cache key.
  def self.safe_ip(req)
    ip = req.ip.to_s
    ip.sub(/\A::ffff:/, "")
  end

  # Safely read the JSON body for login/signup to throttle by email.
  # Returns the normalised email string or nil.
  def self.login_email(req)
    body = req.body.read
    req.body.rewind
    parsed = JSON.parse(body)
    parsed.dig("user", "email").to_s.downcase.strip.presence
  rescue
    nil
  end

  # ── Global rate limit ────────────────────────────────────────────────────────

  # 200 requests per 5 minutes per IP — protects all endpoints from scrapers.
  throttle("req/ip", limit: 200, period: 5.minutes) do |req|
    safe_ip(req) unless req.path.start_with?("/assets", "/packs", "/up")
  end

  # ── Authentication endpoints ─────────────────────────────────────────────────

  # Login — per IP: 5 attempts / 20 seconds.
  # Enough for a legitimate user who fat-fingers their password a couple of times;
  # too slow for automated credential stuffing.
  throttle("login/ip", limit: 5, period: 20.seconds) do |req|
    safe_ip(req) if req.path == "/login" && req.post?
  end

  # Login — per EMAIL: 10 attempts / 5 minutes (distributed attack protection).
  # Even if an attacker rotates IPs, they can only try 10 passwords per 5 min
  # per target email before being throttled. Complements Devise lockable.
  throttle("login/email", limit: 10, period: 5.minutes) do |req|
    login_email(req) if req.path == "/login" && req.post?
  end

  # Signup — per IP: 5 accounts / minute.
  throttle("signup/ip", limit: 5, period: 1.minute) do |req|
    safe_ip(req) if req.path == "/signup" && req.post?
  end

  # Tenant creation — unauthenticated endpoint; limit to 3 / hour per IP.
  throttle("tenants/ip", limit: 3, period: 1.hour) do |req|
    safe_ip(req) if req.path == "/tenants" && req.post?
  end

  # Password reset requests — prevent email flooding.
  throttle("password_reset/ip", limit: 5, period: 10.minutes) do |req|
    safe_ip(req) if req.path.start_with?("/password") && req.post?
  end

  # AI endpoints — public, but expensive; throttle aggressively.
  throttle("ai/ip", limit: 20, period: 1.minute) do |req|
    safe_ip(req) if req.path.start_with?("/ai/")
  end

  # ── Blocklist ────────────────────────────────────────────────────────────────

  # Block IPs that hit the login endpoint with > 30 attempts in 5 min.
  # These are almost certainly automated attacks — ban for the period.
  blocklist("brute_force/ip") do |req|
    Rack::Attack::Allow2Ban.filter(safe_ip(req), maxretry: 30, findtime: 5.minutes, bantime: 1.hour) do
      req.path == "/login" && req.post?
    end
  end

  # ── Throttled response ───────────────────────────────────────────────────────

  # Return 429 with Retry-After header. Generic message — don't reveal
  # which specific throttle was hit.
  self.throttled_responder = lambda do |env|
    match_data = env["rack.attack.match_data"]
    now        = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])

    [
      429,
      {
        "Content-Type"  => "application/json",
        "Retry-After"   => retry_after.to_s
      },
      [{ error: "Too many requests. Please slow down and try again later." }.to_json]
    ]
  end

  # Blocked requests return 403 (not 429) so attackers can't distinguish
  # rate-limit from block.
  self.blocklisted_responder = lambda do |_env|
    [403, { "Content-Type" => "application/json" }, [{ error: "Forbidden." }.to_json]]
  end
end
