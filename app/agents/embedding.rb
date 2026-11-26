module Embedding
  DIMENSIONS = 1024

  def self.provider
    @provider ||= ENV.fetch("EMBEDDING_PROVIDER", "mock") == "bedrock" ? Embedding::Bedrock.new : Embedding::Mock.new
  end

  def self.reset! = @provider = nil

  # Minimum cosine similarity for an answer to count as grounded.
  def self.min_confidence
    ENV.fetch("RETRIEVAL_MIN_CONFIDENCE") { ENV.fetch("EMBEDDING_PROVIDER", "mock") == "bedrock" ? "0.30" : "0.25" }.to_f
  end
end
