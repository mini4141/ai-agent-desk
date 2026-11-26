# HS256 JWTs: "user" tokens for the console/API, "widget" tokens scoped to one conversation.
module AuthToken
  ALGORITHM = "HS256".freeze

  def self.secret = ENV.fetch("JWT_SECRET", "dev-only-change-me")

  def self.encode(payload, expires_in: 12.hours)
    JWT.encode(payload.merge(exp: expires_in.from_now.to_i), secret, ALGORITHM)
  end

  def self.decode(token)
    JWT.decode(token.to_s, secret, true, algorithm: ALGORITHM).first
  rescue JWT::DecodeError
    nil
  end
end
