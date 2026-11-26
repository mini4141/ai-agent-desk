# Hold-to-talk audio: PCM16 16 kHz frames -> (Transcribe | mock) -> AgentRun. Replies are rendered by the
# conversation's channel adapter on the ConversationChannel stream.
class VoiceChannel < ApplicationCable::Channel
  def subscribed
    @conversation = current_conversation
    reject unless @conversation
  end

  def audio_start(data)
    @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @buffer = UtteranceBuffer.new(locale: locale(data), sample_rate: 16_000, on_partial: ->(text) { partial(text) })
  end

  def audio(data)
    @buffer&.push(data["seq"], Base64.decode64(data["pcm"].to_s))
  end

  def audio_end(data)
    return unless @buffer

    buffer, @buffer = @buffer, nil
    in_company(@conversation.company, trace: data["traceparent"]) do
      text = buffer.finish(total: data["total"], hint: data["hint"])
      stt_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at) * 1000).round
      ConversationChannel.broadcast_to(@conversation, { type: "transcript", text:, final: true, stt_ms: })
      AgentRun.new(@conversation.reload).call(text) if text.present?
    end
  end

  private

  def locale(data) = data["lang"].presence || @conversation.language || @conversation.company.locale

  def partial(text) = ConversationChannel.broadcast_to(@conversation, { type: "transcript", text:, final: false })
end
