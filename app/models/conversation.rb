class Conversation < ApplicationRecord
  acts_as_tenant :company
  belongs_to :assignee, class_name: "User", optional: true
  has_many :messages, dependent: :destroy

  enum :channel, { web_chat: "web_chat", voice_web: "voice_web", avatar: "avatar", phone_sim: "phone_sim" }, validate: true
  enum :status, { ai: "ai", waiting_human: "waiting_human", human: "human", resolved: "resolved" }, validate: true

  PRIORITY_SQL = Arel.sql(
    "CASE conversations.status WHEN 'waiting_human' THEN 0 WHEN 'human' THEN 1 WHEN 'ai' THEN 2 ELSE 3 END, " \
    "conversations.last_message_at DESC NULLS LAST"
  )

  scope :inbox, -> { where.not(status: "resolved").order(PRIORITY_SQL) }

  after_commit :notify_changes

  def escalate!(reason)
    update!(status: "waiting_human", escalation_reason: reason, human_involved: true)
    Telemetry.handoff(reason)
  end

  def assign!(user)
    update!(status: "human", assignee: user, human_involved: true)
  end

  def handback!
    update!(status: "ai", assignee: nil, draft_reply: nil)
  end

  def resolve!
    update!(status: "resolved", resolved_at: Time.current)
    WebhookJob.perform_async(id)
  end

  def human_handling? = waiting_human? || human?

  def as_api
    { id:, channel:, status:, assignee_id:, variant:, language:, mode:, csat:, started_at:, resolved_at:,
      messages_count:, last_message_at:, last_message_preview:, draft_reply:, tags:, intake:, escalation_reason: }
  end

  private

  def notify_changes
    InboxChannel.notify(company_id, { type: "conversation_updated", id: id, status: status })
    return unless saved_change_to_status? && !previously_new_record?

    ConversationChannel.broadcast_to(self, { type: "status", status: status, operator: assignee&.name })
  end
end
