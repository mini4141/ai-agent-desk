class Message < ApplicationRecord
  belongs_to :conversation, counter_cache: true

  enum :role, { customer: "customer", ai: "ai", operator: "operator", tool: "tool" }, validate: true, prefix: :from

  after_create :refresh_conversation_summary
  after_create_commit :broadcast_created

  def as_api
    { id:, role:, content:, citations:, timings:, metadata:, created_at: }
  end

  private

  # The inbox preview shows what the customer (or operator) last said, not the AI's canned replies.
  def refresh_conversation_summary
    attrs = { last_message_at: created_at }
    attrs[:last_message_preview] = content.to_s.truncate(80) if from_customer? || from_operator?
    conversation.update_columns(attrs)
  end

  def broadcast_created
    ConversationChannel.broadcast_to(conversation, { type: "message", message: as_api })
    InboxChannel.notify(conversation.company_id, { type: "conversation_updated", id: conversation_id })
  end
end
