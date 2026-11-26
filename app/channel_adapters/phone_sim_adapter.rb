# Simulated phone line: replies are 8 kHz mu-law audio in Twilio-Media-Streams-shaped events.
# New caller audio (barge-in) sets a flag that stops the frames still being sent.
class PhoneSimAdapter < ChannelAdapter
  FRAME_BYTES = 1600 # 200 ms of 8 kHz mu-law

  def self.cancel!(conversation_id) = Rails.cache.write("phone-cancel:#{conversation_id}", true, expires_in: 5.seconds)
  def self.clear_cancel!(conversation_id) = Rails.cache.delete("phone-cancel:#{conversation_id}")

  def initialize(conversation)
    super
    @splitter = SentenceSplitter.new
    @stream_sid = "MZ#{@conversation.id.to_s.rjust(10, '0')}"
    @finished = false
    @first_audio_at = nil
  end

  def speaks? = true

  def on_token(run_id, text)
    super
    @splitter.push(text).each { |sentence| speak(sentence) }
  end

  def finish
    return if @finished

    @finished = true
    @splitter.flush.each { |sentence| speak(sentence) }
  end

  def first_audio_ms(t0) = @first_audio_at && ((@first_audio_at - t0) * 1000).round

  private

  def speak(sentence)
    text = sentence.gsub(/\[\d+\]/, "").strip
    return if text.empty?

    pcm = Speech.provider.synthesize_pcm8k(text, locale: @conversation.language || "ja")
    ulaw = Mulaw.encode(pcm)
    @first_audio_at ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
    emit("transcript", text:)
    ulaw.each_slice(FRAME_BYTES) do |frame|
      return if Rails.cache.read("phone-cancel:#{@conversation.id}")

      ConversationChannel.broadcast_to(@conversation, {
        type: "media", event: "media", streamSid: @stream_sid,
        media: { track: "outbound", payload: Base64.strict_encode64(frame.pack("C*")) }
      })
      sleep(0.08) # pace slower than real time so a barge-in can still interrupt
    end
    ConversationChannel.broadcast_to(@conversation, { type: "mark", event: "mark", streamSid: @stream_sid, mark: { name: "sentence_done" } })
  end
end
