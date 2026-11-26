require "rails_helper"

RSpec.describe Llm::ThinkingFilter do
  it "hides <thinking> blocks even when the tags are split across chunks" do
    filter = described_class.new
    chunks = ["<thin", "king>考え中</think", "ing>\n\n注文は", "出荷済みです"]
    expect(chunks.map { |c| filter.push(c) }.join + filter.flush).to eq("注文は出荷済みです")
  end
end
