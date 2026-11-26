class Rack::Attack
  Rack::Attack.cache.store = Rails.cache
  self.enabled = !Rails.env.test?

  # Load tests (k6) present a shared token so they are not throttled.
  safelist("load-test") { |req| ENV["LOAD_TEST_TOKEN"].present? && req.get_header("HTTP_X_LOAD_TEST") == ENV["LOAD_TEST_TOKEN"] }

  # Per-IP limits
  throttle("widget/ip", limit: 120, period: 1.minute) { |req| req.ip if req.path.start_with?("/widget/") }
  throttle("login/ip", limit: 10, period: 1.minute) { |req| req.ip if req.path == "/api/v1/session" && req.post? }
  throttle("api/ip", limit: 600, period: 1.minute) { |req| req.ip if req.path.start_with?("/api/") }

  # Per-company limit on widget session creation (public key is in the JSON body).
  throttle("widget/company", limit: 600, period: 1.minute) do |req|
    next unless req.path == "/widget/v1/sessions" && req.post?
    body = req.body.read
    req.body.rewind
    JSON.parse(body)["public_key"]
  rescue JSON::ParserError
    nil
  end

  self.throttled_responder = lambda do |_req|
    [429, { "content-type" => "application/json" }, [{ error: "rate_limited" }.to_json]]
  end
end
