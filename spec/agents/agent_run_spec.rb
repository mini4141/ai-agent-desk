require "rails_helper"

RSpec.describe AgentRun do
  let(:company) { create(:company) }
  let(:conversation) { in_tenant(company) { create(:conversation, company:) } }

  before do
    ENV["MOCK_FIRST_TOKEN_DELAY_MS"] = ENV["MOCK_TOKEN_DELAY_MS"] = "0"
    seed_knowledge(company, [["注文した商品はいつ届きますか？", "通常、ご注文から2〜3営業日でお届けします。"],
                             ["返品はできますか？", "商品到着から14日以内なら返品を承ります。"]])
  end

  it "answers from the company knowledge with a citation and per-stage timings" do
    in_tenant(company) { described_class.new(conversation).call("返品はできますか？") }

    message = in_tenant(company) { conversation.messages.from_ai.last }
    expect(message.content).to include("14日以内")
    expect(message.citations.first).to include("title" => "配送について")
    expect(message.timings).to include("retrieval_ms", "llm_first_token_ms", "end_to_end_ms")
  end

  it "calls the company workflow tool, signed with HMAC, and answers from its result" do
    tool = in_tenant(company) { create(:tool, company:) }
    body = { order_id: "A-1023" }.to_json
    signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', tool.encrypted_secret, body)}"
    stub = stub_request(:post, tool.endpoint).with(body:, headers: { "X-Signature" => signature })
             .to_return(status: 200, body: { order_id: "A-1023", status: "出荷済み", eta: "11月28日", carrier: "ヤマト運輸" }.to_json)

    in_tenant(company) { described_class.new(conversation).call("注文 A-1023 はいつ届きますか？") }

    expect(stub).to have_been_requested
    in_tenant(company) do
      expect(conversation.reload.tool_called).to be(true)
      expect(conversation.messages.from_tool.last.metadata).to include("name" => "check_order_status")
      expect(conversation.messages.from_ai.last.content).to include("出荷済み")
    end
  end

  it "hands off to a human with an AI-drafted reply when the customer asks for a person" do
    in_tenant(company) { described_class.new(conversation).call("人と話したいです") }

    in_tenant(company) do
      conversation.reload
      expect(conversation).to be_waiting_human
      expect(conversation.escalation_reason).to eq("customer_request")
      expect(conversation.draft_reply).to be_present
    end
  end

  it "hands off on low retrieval confidence" do
    in_tenant(company) { described_class.new(conversation).call("今日の天気は晴れですか") }
    expect(in_tenant(company) { conversation.reload.escalation_reason }).to eq("low_confidence")
  end

  it "serves a repeated question from the Redis answer cache" do
    in_tenant(company) do
      described_class.new(conversation).call("返品はできますか？")
      run = described_class.new(create(:conversation, company:))
      run.call("返品はできますか？")
      expect(run.timings["cache_hit"]).to be(true)
    end
  end
end
