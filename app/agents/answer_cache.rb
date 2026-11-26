# Redis-backed cache for frequent, tool-free answers (keyed by company + normalised question).
module AnswerCache
  TTL = 10.minutes

  def self.key(company_id, text, locale)
    "answer:#{company_id}:#{locale}:#{Digest::SHA1.hexdigest(text.to_s.downcase.gsub(/[\s[:punct:]。、？！]/, ''))}"
  end

  def self.read(company_id, text, locale)
    Rails.cache.read(key(company_id, text, locale)).tap { |v| Telemetry.cache(v ? :hit : :miss) }
  end

  def self.write(company_id, text, locale, value)
    Rails.cache.write(key(company_id, text, locale), value, expires_in: TTL)
  end
end
