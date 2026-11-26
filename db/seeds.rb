# Demo data: two companies (ja + en), operators, workflow tools, ingested knowledge, the greeting_v2 flag and
# ~400 simulated conversations (flagged simulated=true) so the dashboards are never empty.
# Safe to re-run.
password = ENV.fetch("SEED_PASSWORD", "agentdesk-demo")
backend = ENV.fetch("COMPANY_BACKEND_URL", "http://company-backend:4567")
tool_secret = ENV.fetch("TOOL_HMAC_SECRET", "dev-tool-secret")

COMPANIES = [
  {
    slug: "mirai", name: "ミライ電機", locale: "ja", public_key: "pk_demo_mirai",
    users: [["owner@mirai.example", "山田 太郎", "owner"], ["sato@mirai.example", "佐藤 花子", "operator"]],
    settings: {
      "greeting" => "こんにちは！ミライ電機です。ご用件をどうぞ。",
      "greeting_v2" => "こんにちは！ミライ電機のAIアシスタントです。よくあるご質問はこちらから選べます。",
      "suggested_questions" => ["注文 A-1023 はいつ届きますか？", "返品の方法を教えてください", "折り返し電話を依頼したい"]
    }
  },
  {
    slug: "harbor", name: "Harbor Outdoor", locale: "en", public_key: "pk_demo_harbor",
    users: [["owner@harbor.example", "Olivia Owner", "owner"], ["sam@harbor.example", "Sam Operator", "operator"]],
    settings: {
      "greeting" => "Hi! Harbor Outdoor support here. How can I help?",
      "greeting_v2" => "Hi! I'm Harbor's AI assistant. Pick a question below or ask your own.",
      "suggested_questions" => ["Where is order H-2001?", "What is your return policy?", "Can I book a callback?"]
    }
  }
].freeze

TOOLS = [
  { name: "check_order_status", description: "Look up the status and delivery date of an order by its order id (e.g. A-1023).",
    path: "/tools/check_order_status",
    schema: { "type" => "object", "properties" => { "order_id" => { "type" => "string", "description" => "Order id such as A-1023" } }, "required" => ["order_id"] } },
  { name: "book_callback", description: "Book a callback from a human agent at a phone number and time (HH:MM).",
    path: "/tools/book_callback",
    schema: { "type" => "object", "properties" => { "phone" => { "type" => "string" }, "time" => { "type" => "string", "description" => "HH:MM" } }, "required" => %w[phone time] } }
].freeze

Flipper.enable_percentage_of_actors(:greeting_v2, 50) unless Flipper[:greeting_v2].percentage_of_actors_value.positive?

COMPANIES.each do |attrs|
  company = Company.find_or_initialize_by(slug: attrs[:slug])
  company.assign_attributes(name: attrs[:name], locale: attrs[:locale], public_key: attrs[:public_key],
                            settings: attrs[:settings].merge("webhook_url" => "#{backend}/webhooks/conversation"),
                            webhook_secret: tool_secret, allowed_origins: [])
  company.save!

  ActsAsTenant.with_tenant(company) do
    attrs[:users].each do |email, name, role|
      User.find_or_create_by!(email:) { |u| u.assign_attributes(name:, role:, password:) }
    end

    TOOLS.each do |t|
      tool = Tool.find_or_initialize_by(name: t[:name])
      tool.update!(description: t[:description], params_schema: t[:schema], endpoint: "#{backend}#{t[:path]}", encrypted_secret: tool_secret)
    end

    unless ENV["SEED_SKIP_INGEST"] == "1"
      Dir[Rails.root.join("mocks/demo-sites", company.slug, "*.html")].sort.each do |file|
        page = File.basename(file)
        next if page == "index.html"

        url = "#{backend}/sites/#{company.slug}/#{page}"
        source = KnowledgeSource.find_or_create_by!(url:) { |s| s.kind = "url" }
        IngestSourceJob.new.perform(source.id, company.id) unless source.ready?
      end
    end
  end
end

# ---- simulated history -------------------------------------------------------------------------
if ENV["SEED_SIMULATED"] != "0"
  company = Company.find_by!(slug: "mirai")
  ActsAsTenant.with_tenant(company) do
    next if Conversation.where(simulated: true).exists?

    rng = Random.new(2026)
    channels = { "web_chat" => 0.6, "voice_web" => 0.15, "avatar" => 0.1, "phone_sim" => 0.15 }
    pick = lambda do
      r = rng.rand
      channels.each { |c, w| return c if (r -= w) < 0 }
      "web_chat"
    end
    base = { "web_chat" => 420, "voice_web" => 900, "avatar" => 950, "phone_sim" => 1100 }

    rows = 400.times.map do |i|
      started = Time.current - rng.rand(14 * 24 * 3600) - 1800
      variant = i.even? ? "control" : "greeting_v2"
      channel = pick.call
      human = rng.rand > (variant == "greeting_v2" ? 0.76 : 0.64)
      resolved = rng.rand < 0.96
      responded = rng.rand < 0.7
      csat = responded && resolved ? (rng.rand < (human ? 0.6 : 0.88) ? 5 : 1) : nil
      handle = human ? rng.rand(300..900) : rng.rand(40..240)
      { company_id: company.id, channel:, status: resolved ? "resolved" : "ai", variant:, language: "ja", mode: "chat",
        started_at: started, resolved_at: resolved ? started + handle : nil, csat:, messages_count: 2, simulated: true,
        human_involved: human, tool_called: rng.rand < (variant == "greeting_v2" ? 0.23 : 0.17),
        last_message_at: started + 30, last_message_preview: "（シミュレーション）", visitor_id: "sim-#{i}", tags: [], intake: {} }
    end
    ids = Conversation.insert_all(rows, returning: %w[id channel started_at]).rows
    messages = ids.flat_map do |id, channel, started|
      started = started.is_a?(String) ? Time.zone.parse(started) : started
      first_token = (base[channel] * 0.35 + rng.rand(-60..90)).clamp(60, 900)
      timings = { "retrieval_ms" => rng.rand(8..40), "llm_first_token_ms" => first_token.round, "llm_total_ms" => (first_token * 2.4).round,
                  "end_to_end_ms" => (base[channel] + rng.rand(-120..220)), "total_ms" => (base[channel] * 1.8).round,
                  "cache_hit" => rng.rand < 0.2 }
      timings["stt_ms"] = rng.rand(180..420) unless channel == "web_chat"
      timings["tts_first_audio_ms"] = rng.rand(250..600) unless channel == "web_chat"
      [
        { conversation_id: id, role: "customer", content: "（シミュレーションされた質問）", citations: [], timings: {}, metadata: {}, created_at: started, updated_at: started },
        { conversation_id: id, role: "ai", content: "（シミュレーションされた回答）", citations: [], timings:, metadata: {}, created_at: started + 2, updated_at: started + 2 }
      ]
    end
    Message.insert_all(messages)
    MetricsRollupJob.new.perform(16)
    puts "seeded #{rows.size} simulated conversations"
  end
end
puts "seed complete"
