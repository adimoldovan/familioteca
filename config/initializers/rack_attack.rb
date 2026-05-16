class Rack::Attack
  self.enabled = !Rails.env.test? || ENV["RACK_ATTACK"] == "1"

  throttle("logins/ip", limit: 10, period: 10.minutes) do |req|
    if req.path == "/session" && req.post?
      req.env["action_dispatch.remote_ip"]&.to_s.presence || req.ip
    end
  end

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    period = match_data[:period].to_i
    retry_after = period.positive? ? (period - (Time.now.to_i % period)).to_s : "600"

    [ 429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after },
      [ "Prea multe încercări. Așteaptă 10 minute." ] ]
  end
end
