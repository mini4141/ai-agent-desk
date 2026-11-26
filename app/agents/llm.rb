# Provider facade. Both providers implement:
#   stream(system:, messages:, tools:, context:, locale:) { |event| ... }
# where event is { type: :token, text: } or { type: :tool_use, id:, name:, input: }.
# Messages use the Bedrock Converse shape so the real provider needs no translation.
module Llm
  def self.provider
    @provider ||= ENV.fetch("LLM_PROVIDER", "mock") == "bedrock" ? Llm::Bedrock.new : Llm::Mock.new
  end

  def self.reset! = @provider = nil

  # Pieces a finished answer into small streaming chunks (used by the mock and the answer cache).
  def self.pieces(text)
    text.scan(/[a-zA-Z0-9'’,.-]+\s*|[^\sa-zA-Z0-9]{1,3}|\s+/)
  end
end
