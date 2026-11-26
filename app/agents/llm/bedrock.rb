# Claude on Amazon Bedrock via the streaming Converse API with tool use.
# If the primary model refuses the call before producing output (access not granted, model not ready, throttled),
# the turn is retried once on BEDROCK_FALLBACK_MODEL_ID so customers still get an answer.
class Llm::Bedrock
  FALLBACK_ERRORS = [Aws::BedrockRuntime::Errors::AccessDeniedException, Aws::BedrockRuntime::Errors::ResourceNotFoundException,
                     Aws::BedrockRuntime::Errors::ThrottlingException, Aws::BedrockRuntime::Errors::ModelNotReadyException].freeze

  attr_reader :last_model

  def stream(system:, messages:, tools:, context: [], locale: "ja", &block)
    models = [ENV.fetch("BEDROCK_MODEL_ID"), ENV["BEDROCK_FALLBACK_MODEL_ID"].presence].compact
    models.shift if models.size > 1 && @primary_down_until && Time.now < @primary_down_until # skip a model that just refused us
    models.each_with_index do |model_id, i|
      started = false
      begin
        @last_model = model_id
        return converse(model_id, system:, messages:, tools:) { |event| started = true; block.call(event) }
      rescue *FALLBACK_ERRORS => e
        raise if started || i == models.size - 1

        @primary_down_until = Time.now + 300
        Rails.logger.warn("bedrock model #{model_id} failed (#{e.class}); falling back to #{models[i + 1]}")
      end
    end
  end

  private

  def converse(model_id, system:, messages:, tools:)
    params = {
      model_id: model_id,
      system: [{ text: system }],
      messages: messages,
      inference_config: { max_tokens: 700, temperature: 0.2 }
    }
    params[:tool_config] = { tools: tools } unless tools.empty?

    current = nil
    filter = Llm::ThinkingFilter.new
    Telemetry.span("bedrock.converse_stream", model: model_id) do
      client.converse_stream(**params) do |events|
        events.on_content_block_start_event do |e|
          tu = e.start&.tool_use
          current = { id: tu.tool_use_id, name: tu.name, json: +"" } if tu
        end
        events.on_content_block_delta_event do |e|
          if e.delta.text
            visible = filter.push(e.delta.text)
            yield({ type: :token, text: visible }) unless visible.empty?
          elsif e.delta.tool_use && current
            current[:json] << e.delta.tool_use.input.to_s
          end
        end
        events.on_content_block_stop_event do
          tail = filter.flush
          yield({ type: :token, text: tail }) unless tail.empty?
          if current
            input = current[:json].empty? ? {} : JSON.parse(current[:json])
            yield({ type: :tool_use, id: current[:id], name: current[:name], input: })
            current = nil
          end
        end
      end
    end
  end

  def client
    @client ||= Aws::BedrockRuntime::Client.new(region: ENV.fetch("AWS_REGION", "ap-southeast-2"))
  end
end
