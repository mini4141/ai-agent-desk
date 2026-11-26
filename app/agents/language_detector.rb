module LanguageDetector
  JAPANESE = /[\p{Hiragana}\p{Katakana}\p{Han}]/

  def self.detect(text, fallback = "ja")
    letters = text.to_s.scan(/\p{L}/)
    return fallback if letters.empty?

    (letters.count { |c| c.match?(JAPANESE) }.to_f / letters.size) > 0.3 ? "ja" : "en"
  end
end
