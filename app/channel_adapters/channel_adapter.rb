# A channel adapter turns channel input into text turns (done by the channel classes) and renders
# the agent's output back in the channel's own form: text tokens, TTS audio + visemes, or mu-law frames.
# AgentRun only talks to this interface.
class ChannelAdapter
  ADAPTERS = {
    "web_chat" => "WebChatAdapter", "voice_web" => "VoiceWebAdapter",
    "avatar" => "AvatarAdapter", "phone_sim" => "PhoneSimAdapter"
  }.freeze

  def self.for(conversation) = ADAPTERS.fetch(conversation.channel).constantize.new(conversation)

  FLUSH_INTERVAL = 0.03 # seconds: the first token goes out immediately, later ones are coalesced

  def initialize(conversation)
    @conversation = conversation
    @stream = ConversationChannel.broadcasting_for(conversation)
    @pending = +""
    @last_flush = nil
  end

  def speaks? = false

  def on_token(run_id, text)
    @run_id = run_id
    @pending << text
    flush_tokens if @last_flush.nil? || monotonic - @last_flush >= FLUSH_INTERVAL
  end

  def on_tool(name, _input, output) = emit("tool", name:, ok: !output.key?("error"))

  def finish = flush_tokens

  def first_audio_ms(_t0) = nil

  private

  def emit(type, **payload) = ActionCable.server.broadcast(@stream, { type: }.merge(payload))

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def flush_tokens
    return if @pending.empty?

    emit("token", run_id: @run_id, text: @pending)
    @pending = +""
    @last_flush = monotonic
  end
end
