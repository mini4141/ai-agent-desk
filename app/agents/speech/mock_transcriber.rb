# Offline STT stand-in. It counts audio bytes and returns the caller-supplied hint (or a canned
# phrase), so the full audio path - frames over Action Cable -> transcript -> agent - runs without AWS.
class Speech::MockTranscriber
  DEFAULTS = { "ja" => "注文 A-1023 はいつ届きますか？", "en" => "When will order A-1023 arrive?" }.freeze

  attr_reader :bytes

  def initialize(locale)
    @locale = locale
    @bytes = 0
  end

  def push(chunk) = @bytes += chunk.bytesize

  def finish(hint: nil) = hint.presence || DEFAULTS.fetch(@locale, DEFAULTS["en"])
end
