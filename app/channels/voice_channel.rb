# Hold-to-talk audio: PCM16 16 kHz frames -> (Transcribe | mock) -> AgentRun. Replies are rendered by the
# conversation's channel adapter on the ConversationChannel stream.
class VoiceChannel < ApplicationCable::Channel
  def subscribed
    @conversation = current_conversation
    @mutex = Mutex.new
    reject unless @conversation
  end

  # Action Cable runs messages on a thread pool, so audio_start, audio frames and audio_end can be handled in any
  # order. Whichever arrives first creates the utterance buffer.
  def audio_start(data) = buffer_for(data)

  def audio(data) = buffer_for(data).push(data["seq"], Base64.decode64(data["pcm"].to_s))

  def audio_end(data)
    buffer = buffer_for(data)
    @mutex.synchronize { @buffer = nil }
    in_company(@conversation.company, trace: data["traceparent"]) do
      text = buffer.finish(total: data["total"], hint: data["hint"])
      stt_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at) * 1000).round
      @started_at = nil
      ConversationChannel.broadcast_to(@conversation, { type: "transcript", text:, final: true, stt_ms: })
      AgentRun.new(@conversation.reload).call(text) if text.present?
    end
  end

  private

  def buffer_for(data)
    @mutex.synchronize do
      @started_at ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @buffer ||= UtteranceBuffer.new(locale: locale(data), sample_rate: 16_000, on_partial: ->(text) { partial(text) })
    end
  end

  # The widget sends BCP-47 tags ("ja-JP"); providers use the two-letter locale ("ja").
  def locale(data) = (data["lang"].presence || @conversation.language || @conversation.company.locale).to_s.first(2)

  def partial(text) = ConversationChannel.broadcast_to(@conversation, { type: "transcript", text:, final: false })
end
