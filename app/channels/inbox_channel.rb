# Operators receive "conversation_updated" pings; the console invalidates its TanStack Query cache on them.
class InboxChannel < ApplicationCable::Channel
  def self.stream(company_id) = "inbox:#{company_id}"
  def self.notify(company_id, payload) = ActionCable.server.broadcast(stream(company_id), payload)

  def subscribed
    return reject unless current_user

    stream_from self.class.stream(current_user.company_id)
  end
end
