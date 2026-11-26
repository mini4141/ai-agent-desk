# Phone-line simulator endpoint (/phone-sim/stream). Carries Twilio-Media-Streams-shaped events:
#   start  { start: { streamSid, callSid } }
#   media  { media: { payload: <base64 8 kHz mu-law> }, sequenceNumber }
#   mark   { mark: { name: "utterance_end", total, hint } }   (end of caller utterance)
#   stop
# Replies come back on the same conversation stream as `media` / `mark` / `clear` events.
class PhoneStreamChannel < ApplicationCable::Channel
  SPEECH_ENERGY = 1500

  def subscribed
    @conversation = current_conversation
    return reject unless @conversation

    stream_for @conversation
  end

  def event(data)
    case data["event"]
    when "start" then start_call(data)
    when "media" then media(data)
    when "mark" then utterance_end(data) if data.dig("mark", "name") == "utterance_end"
    when "stop" then Rails.cache.delete("phone-speaking:#{@conversation.id}")
    end
  end

  private

  def start_call(data)
    @stream_sid = data.dig("start", "streamSid")
    @conversation.update_columns(channel: "phone_sim") unless @conversation.phone_sim?
    PhoneSimAdapter.clear_cancel!(@conversation.id)
  end

  def media(data)
    ulaw = Base64.decode64(data.dig("media", "payload").to_s)
    pcm = Mulaw.decode(ulaw)
    if speaking? && rms(pcm) > SPEECH_ENERGY
      # Barge-in: the caller talks over the agent, so stop sending TTS audio.
      PhoneSimAdapter.cancel!(@conversation.id)
      ConversationChannel.broadcast_to(@conversation, { type: "clear", event: "clear", streamSid: @stream_sid })
    end
    buffer.push(data["sequenceNumber"], pcm)
  end

  def utterance_end(data)
    return unless @buffer

    buf, @buffer = @buffer, nil
    in_company(@conversation.company) do
      text = buf.finish(total: data.dig("mark", "total"), hint: data.dig("mark", "hint"))
      return if text.blank?

      PhoneSimAdapter.clear_cancel!(@conversation.id)
      Rails.cache.write("phone-speaking:#{@conversation.id}", true, expires_in: 60.seconds)
      AgentRun.new(@conversation.reload).call(text)
    ensure
      Rails.cache.delete("phone-speaking:#{@conversation.id}")
    end
  end

  def buffer = @buffer ||= UtteranceBuffer.new(locale: @conversation.company.locale, sample_rate: 8000)

  def speaking? = Rails.cache.read("phone-speaking:#{@conversation.id}")

  def rms(pcm)
    samples = pcm.unpack("s<*")
    return 0 if samples.empty?

    Math.sqrt(samples.sum { |s| s * s } / samples.size)
  end
end
