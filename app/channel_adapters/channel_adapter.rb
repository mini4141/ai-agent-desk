# A channel adapter turns channel input into text turns (done by the channel classes) and renders
# the agent's output back in the channel's own form: text tokens, TTS audio + visemes, or mu-law frames.
# AgentRun only talks to this interface.
class ChannelAdapter
  ADAPTERS = {
    "web_chat" => "WebChatAdapter", "voice_web" => "VoiceWebAdapter",
    "avatar" => "AvatarAdapter", "phone_sim" => "PhoneSimAdapter"
  }.freeze

  def self.for(conversation) = ADAPTERS.fetch(conversation.channel).constantize.new(conversation)

  def initialize(conversation)
    @conversation = conversation
  end

  def speaks? = false

  def on_token(run_id, text) = emit("token", run_id:, text:)

  def on_tool(name, _input, output) = emit("tool", name:, ok: !output.key?("error"))

  def finish; end

  def first_audio_ms(_t0) = nil

  private

  def emit(type, **payload) = ConversationChannel.broadcast_to(@conversation, { type: }.merge(payload))
end
