# Customer PII (emails, phone numbers) is redacted before it reaches logs and traces.
module PiiRedactor
  EMAIL = /[\w.+-]+@[\w-]+(?:\.[\w-]+)+/
  PHONE = /(?:\+\d[\d\s-]{8,}\d)|(?<![\d-])0\d{1,3}[-\s]?\d{2,4}[-\s]?\d{3,4}(?![\d-])/

  JWT_LIKE = /eyJ[\w-]+\.[\w-]+\.[\w-]+/

  def self.redact(text)
    text.to_s.gsub(EMAIL, "[email]").gsub(PHONE, "[phone]").gsub(JWT_LIKE, "[token]")
  end
end
