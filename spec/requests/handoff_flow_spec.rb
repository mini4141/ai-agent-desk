require "rails_helper"

RSpec.describe "Operator takeover", type: :request do
  let(:company) { create(:company) }
  let(:operator) { in_tenant(company) { create(:user, company:) } }
  let(:conversation) { in_tenant(company) { create(:conversation, company:, status: "waiting_human", draft_reply: "確認します") } }

  it "lets an operator take over, reply, hand back and resolve" do
    post "/api/v1/conversations/#{conversation.id}/messages", params: { content: "担当の佐藤です" }, headers: bearer(operator)
    expect(response).to have_http_status(:created)
    in_tenant(company) { expect(conversation.reload).to be_human }

    post "/api/v1/conversations/#{conversation.id}/handback", headers: bearer(operator)
    in_tenant(company) { expect(conversation.reload).to be_ai }

    post "/api/v1/conversations/#{conversation.id}/resolve", headers: bearer(operator)
    in_tenant(company) { expect(conversation.reload).to be_resolved }
    expect(WebhookJob.jobs.size).to eq(1)
  end

  it "lists the inbox without N+1 queries (Bullet raises otherwise)" do
    in_tenant(company) { 3.times { create(:conversation, company:) } }
    get "/api/v1/conversations", headers: bearer(operator)
    expect(response.parsed_body["conversations"].size).to eq(3)
  end
end
