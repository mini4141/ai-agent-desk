# Live conversation stream. Customers send `ask`; operators subscribe (with id) to watch.
# Replies stream back as token / message / speak / status events; `draft` events go to operators only.
class ConversationChannel < ApplicationCable::Channel
  MAX_TEXT = 2000

  def self.broadcast_ops(conversation, payload)
    ActionCable.server.broadcast("conversation:#{conversation.id}:ops", payload)
  end

  def subscribed
    @conversation = resolve_conversation
    return reject unless @conversation

    stream_for @conversation
    stream_from "conversation:#{@conversation.id}:ops" if current_user
    in_company(@conversation.company) do
      transmit({ type: "history", status: @conversation.status, draft: (current_user ? @conversation.draft_reply : nil),
                 messages: @conversation.messages.order(:created_at).last(50).map(&:as_api) })
    end
  end

  def ask(data)
    return unless current_conversation && @conversation

    text = data["text"].to_s.strip.first(MAX_TEXT)
    return if text.empty?

    in_company(@conversation.company, trace: data["traceparent"]) do
      AgentRun.new(@conversation.reload).call(text)
    end
  end

  private

  def resolve_conversation
    return current_conversation if current_conversation

    ActsAsTenant.with_tenant(current_user.company) { Conversation.find_by(id: params[:id]) } if current_user
  end
end
