# Claude on Amazon Bedrock via the streaming Converse API with tool use.
class Llm::Bedrock
  def stream(system:, messages:, tools:, context: [], locale: "ja")
    params = {
      model_id: ENV.fetch("BEDROCK_MODEL_ID"),
      system: [{ text: system }],
      messages: messages,
      inference_config: { max_tokens: 700, temperature: 0.2 }
    }
    params[:tool_config] = { tools: tools } unless tools.empty?

    current = nil
    Telemetry.span("bedrock.converse_stream", model: params[:model_id]) do
      client.converse_stream(**params) do |events|
        events.on_content_block_start_event do |e|
          tu = e.start&.tool_use
          current = { id: tu.tool_use_id, name: tu.name, json: +"" } if tu
        end
        events.on_content_block_delta_event do |e|
          if e.delta.text
            yield({ type: :token, text: e.delta.text })
          elsif e.delta.tool_use && current
            current[:json] << e.delta.tool_use.input.to_s
          end
        end
        events.on_content_block_stop_event do
          if current
            input = current[:json].empty? ? {} : JSON.parse(current[:json])
            yield({ type: :tool_use, id: current[:id], name: current[:name], input: })
            current = nil
          end
        end
      end
    end
  end

  private

  def client
    @client ||= Aws::BedrockRuntime::Client.new(region: ENV.fetch("AWS_REGION", "ap-southeast-2"))
  end
end
