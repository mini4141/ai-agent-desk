# Browser voice: tokens still stream as text, and TTS starts on the first complete sentence.
class VoiceWebAdapter < ChannelAdapter
  def initialize(conversation)
    super
    @splitter = SentenceSplitter.new
    @seq = 0
    @threads = []
    @first_audio_at = nil
    @finished = false
  end

  def speaks? = true

  def on_token(run_id, text)
    super
    @splitter.push(text).each { |sentence| speak(sentence) }
  end

  def finish
    super
    return if @finished

    @finished = true
    @splitter.flush.each { |sentence| speak(sentence) }
    @threads.each(&:join)
  end

  def first_audio_ms(t0)
    @first_audio_at && ((@first_audio_at - t0) * 1000).round
  end

  private

  def want_visemes? = false

  def speak(sentence)
    text = sentence.gsub(/\[\d+\]/, "").strip
    return if text.empty?

    seq = (@seq += 1)
    @threads << Thread.new do
      payload = Speech.provider.synthesize(text, locale: @conversation.language || "ja", visemes: want_visemes?)
      @first_audio_at ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
      emit("speak", run_id: @run_id, seq:, text:, audio: payload.audio_b64, mime: payload.mime, visemes: payload.visemes)
    end
  end
end
