# Amazon Titan Text Embeddings v2 (1024 dims, normalised).
class Embedding::Bedrock
  def embed(text)
    body = { inputText: text.to_s.truncate(8000), dimensions: Embedding::DIMENSIONS, normalize: true }.to_json
    resp = client.invoke_model(model_id: ENV.fetch("BEDROCK_EMBED_MODEL_ID", "amazon.titan-embed-text-v2:0"),
                               body:, content_type: "application/json", accept: "application/json")
    JSON.parse(resp.body.read).fetch("embedding")
  end

  private

  def client
    @client ||= Aws::BedrockRuntime::Client.new(region: ENV.fetch("AWS_REGION", "ap-southeast-2"))
  end
end
