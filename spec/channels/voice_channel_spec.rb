require "rails_helper"

RSpec.describe VoiceChannel, type: :channel do
  let(:company) { create(:company) }
  let(:conversation) { in_tenant(company) { create(:conversation, company:, channel: "voice_web") } }

  before do
    ENV["MOCK_FIRST_TOKEN_DELAY_MS"] = ENV["MOCK_TOKEN_DELAY_MS"] = "0"
    seed_knowledge(company, [["返品はできますか？", "商品到着から14日以内なら返品を承ります。"]])
    stub_connection current_conversation: conversation, current_user: nil
  end

  it "runs a hold-to-talk utterance through STT and the agent, whatever order the cable messages are handled in" do
    subscribe
    # Action Cable handles messages on a thread pool: here audio_end is processed before the audio frames.
    perform :audio_end, { "total" => 0, "hint" => "返品はできますか？", "lang" => "ja-JP" }
    perform :audio_start, { "lang" => "ja-JP" }
    perform :audio, { "seq" => 0, "pcm" => Base64.strict_encode64("\0" * 3200) }

    in_tenant(company) do
      expect(conversation.messages.from_customer.pluck(:content)).to eq(["返品はできますか？"])
      expect(conversation.messages.from_ai.last.content).to include("14日以内")
    end
  end
end
