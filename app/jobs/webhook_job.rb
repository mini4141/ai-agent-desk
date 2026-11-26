require "net/http"

# Notifies the company's webhook (signed with its encrypted secret) when a conversation is resolved.
class WebhookJob
  include Sidekiq::Job
  sidekiq_options queue: "default", retry: 5

  def perform(conversation_id)
    conversation = ActsAsTenant.without_tenant { Conversation.find(conversation_id) }
    company = conversation.company
    url = company.setting("webhook_url")
    return if url.blank?

    body = { event: "conversation.resolved", conversation_id: conversation.id, channel: conversation.channel, csat: conversation.csat }.to_json
    signature = OpenSSL::HMAC.hexdigest("SHA256", company.webhook_secret.to_s, body)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 5) do |http|
      http.post(uri.request_uri, body, "Content-Type" => "application/json", "X-Signature" => "sha256=#{signature}")
    end
  end
end
