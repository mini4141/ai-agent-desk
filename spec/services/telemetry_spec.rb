require "rails_helper"

RSpec.describe Telemetry do
  it "emits a CloudWatch EMF line for a stage timing when EMF=1" do
    ENV["EMF"] = "1"
    lines = []
    allow($stdout).to receive(:puts) { |line| lines << line }
    described_class.timing("retrieval_ms", 42, "web_chat")
    emf = JSON.parse(lines.first)
    expect(emf.dig("_aws", "CloudWatchMetrics", 0, "Namespace")).to eq("AgentDesk/Latency")
    expect(emf).to include("retrieval_ms" => 42, "Channel" => "web_chat")
  ensure
    ENV.delete("EMF")
  end
end
