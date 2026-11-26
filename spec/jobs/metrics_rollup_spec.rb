require "rails_helper"

RSpec.describe MetricsRollupJob do
  it "rolls conversations up per day, channel and variant and reports the experiment delta" do
    company = create(:company)
    in_tenant(company) do
      now = Time.current
      3.times { create(:conversation, company:, variant: "greeting_v2", status: "resolved", resolved_at: now + 60, csat: 5) }
      2.times { create(:conversation, company:, variant: "control", status: "resolved", resolved_at: now + 60, human_involved: true) }

      described_class.new.perform(1, company.id)
      rollup = MetricRollup.find_by!(variant: "greeting_v2", channel: "web_chat")
      expect(rollup.metrics).to include("conversations" => 3, "deflected" => 3)

      report = MetricsReport.new(from: Time.zone.today, to: Time.zone.today).call
      expect(report[:totals][:conversations]).to eq(5)
      expect(report[:experiment][:deflection_delta_pp]).to eq(100.0)
      expect(report[:experiment][:note]).to include("Sample too small")
    end
  end
end
