require "rails_helper"

RSpec.describe ConversationChannel, type: :channel do
  let(:company) { create(:company) }
  let(:conversation) { in_tenant(company) { create(:conversation, company:) } }

  before do
    ENV["MOCK_FIRST_TOKEN_DELAY_MS"] = ENV["MOCK_TOKEN_DELAY_MS"] = "0"
    seed_knowledge(company, [["返品はできますか？", "商品到着から14日以内なら返品を承ります。"]])
    stub_connection current_conversation: conversation, current_user: nil
  end

  it "streams tokens and the final answer for a customer message" do
    subscribe
    expect(subscription).to be_confirmed
    expect(transmissions.last).to include("type" => "history")

    expect { perform :ask, { "text" => "返品はできますか？" } }
      .to have_broadcasted_to(conversation).with(hash_including("type" => "token")).at_least(:once)

    final = in_tenant(company) { conversation.messages.from_ai.last }
    expect(final.content).to include("14日以内")
  end
end
