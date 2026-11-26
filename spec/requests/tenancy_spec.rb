require "rails_helper"

RSpec.describe "Tenancy and authorisation", type: :request do
  let(:company_a) { create(:company) }
  let(:company_b) { create(:company) }
  let(:operator_a) { in_tenant(company_a) { create(:user, company: company_a, role: "operator") } }
  let(:owner_a) { in_tenant(company_a) { create(:user, company: company_a, role: "owner") } }

  it "never lets company A read company B conversations" do
    foreign = in_tenant(company_b) { create(:conversation, company: company_b) }
    mine = in_tenant(company_a) { create(:conversation, company: company_a) }

    get "/api/v1/conversations", headers: bearer(operator_a)
    expect(response.parsed_body["conversations"].pluck("id")).to eq([mine.id])

    get "/api/v1/conversations/#{foreign.id}", headers: bearer(operator_a)
    expect(response).to have_http_status(:not_found)
  end

  it "keeps admin settings (workflow tools) away from operators but open to owners" do
    in_tenant(company_a) { create(:tool, company: company_a) }

    get "/api/v1/tools", headers: bearer(operator_a)
    expect(response).to have_http_status(:forbidden)

    get "/api/v1/tools", headers: bearer(owner_a)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["tools"].size).to eq(1)
  end

  it "rejects unauthenticated requests" do
    get "/api/v1/conversations"
    expect(response).to have_http_status(:unauthorized)
  end

  it "signs in with email and password and returns a JWT" do
    user = owner_a
    post "/api/v1/session", params: { email: user.email, password: "password123" }
    expect(response).to have_http_status(:ok)
    expect(AuthToken.decode(response.parsed_body["token"])["sub"]).to eq(user.id)
  end
end
