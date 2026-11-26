# Amazon Polly neural TTS. Viseme speech marks come from a second call in JSON output format.
class Speech::Polly
  VOICES = { "ja" => ENV.fetch("POLLY_VOICE_JA", "Tomoko"), "en" => ENV.fetch("POLLY_VOICE_EN", "Joanna") }.freeze
  LANGUAGE = { "ja" => "ja-JP", "en" => "en-US" }.freeze

  def synthesize(text, locale: "ja", visemes: false)
    audio = marks = nil
    threads = [Thread.new { audio = request(text, locale, output_format: "mp3").audio_stream.read }]
    threads << Thread.new { marks = parse_marks(request(text, locale, output_format: "json", speech_mark_types: ["viseme"]).audio_stream.read) } if visemes
    threads.each(&:join)
    Speech::Result.new(audio_b64: Base64.strict_encode64(audio), mime: "audio/mpeg", visemes: marks || [])
  end

  def synthesize_pcm8k(text, locale: "ja")
    request(text, locale, output_format: "pcm", sample_rate: "8000").audio_stream.read
  end

  private

  def request(text, locale, **opts)
    Telemetry.span("polly.synthesize", locale:) do
      client.synthesize_speech(text:, voice_id: VOICES.fetch(locale, VOICES["en"]), engine: "neural",
                               language_code: LANGUAGE.fetch(locale, "en-US"), **opts)
    end
  end

  def parse_marks(body) = body.lines.filter_map { |l| JSON.parse(l) if l.strip.start_with?("{") }.map { |m| m.slice("time", "value") }

  def client = @client ||= Aws::Polly::Client.new(region: ENV.fetch("AWS_REGION", "ap-southeast-2"))
end
