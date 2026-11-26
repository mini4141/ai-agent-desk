# One customer turn: language detection -> escalation check -> answer cache -> retrieval ->
# streaming LLM (with tool use) -> citations. Channel-specific output goes through the adapter,
# so adding a channel never touches this class.
class AgentRun
  MAX_TOOL_ROUNDS = 3

  attr_reader :timings

  def initialize(conversation, adapter: ChannelAdapter.for(conversation), stt_ms: nil)
    @conversation = conversation
    @company = conversation.company
    @adapter = adapter
    @timings = { "stt_ms" => stt_ms }.compact
    @run_id = SecureRandom.hex(6)
  end

  def call(text)
    @t0 = now - (@timings["stt_ms"].to_f / 1000)
    Telemetry.span("agent.run", channel: @conversation.channel, conversation_id: @conversation.id) do
      @conversation.messages.create!(role: "customer", content: text)
      return draft_for_operator(text) if @conversation.human_handling?

      @locale = LanguageDetector.detect(text, @company.locale)
      @conversation.update_columns(language: @locale) if @conversation.language != @locale
      return intake_turn(text) if @conversation.mode == "interview" && !@conversation.intake["completed"]
      return escalate(Escalation.reason_for(text), text) if Escalation.reason_for(text)

      answer_turn(text)
    end
  ensure
    @adapter.finish
  end

  private

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  def ms_since(t) = ((now - t) * 1000).round

  def answer_turn(text)
    cached = AnswerCache.read(@company.id, text, @locale)
    return reply_from_cache(cached) if cached

    retrieval = Telemetry.span("retrieval") { Retriever.new.call(text) }
    @timings["retrieval_ms"] = retrieval.ms
    tool_intent = text.match?(Llm::Mock::ORDER_ID) || text.match?(/折り返し|callback/i)
    return escalate("low_confidence", text) if retrieval.confidence < Embedding.min_confidence && !tool_intent

    chunks = retrieval.chunks.select { |c| 1 - c.neighbor_distance >= Embedding.min_confidence }.uniq(&:knowledge_source_id).first(3)
    answer, used_tool = run_llm(text, chunks)
    citations = citations_for(chunks)
    AnswerCache.write(@company.id, text, @locale, { "text" => answer, "citations" => citations }) unless used_tool
    persist_ai_message(answer, citations)
  end

  def run_llm(text, chunks)
    tools = Tool.where(enabled: true).to_a
    specs = tools.map(&:to_spec)
    system = SystemPrompt.build(@company, @locale, chunks)
    context = chunks.map { |c| { text: c.content } }
    messages = history + [{ role: "user", content: [{ text: text }] }]
    answer = +""
    used_tool = false
    llm_started = now

    (MAX_TOOL_ROUNDS + 1).times do
      tool_uses = []
      round_text = +""
      Telemetry.span("llm.stream", provider: ENV.fetch("LLM_PROVIDER", "mock")) do
        Llm.provider.stream(system:, messages:, tools: specs, context:, locale: @locale) do |event|
          case event[:type]
          when :token
            @timings["llm_first_token_ms"] ||= ms_since(llm_started)
            @timings["end_to_end_ms"] ||= ms_since(@t0) unless @adapter.speaks?
            round_text << event[:text]
            @adapter.on_token(@run_id, event[:text])
          when :tool_use then tool_uses << event
          end
        end
      end
      answer << round_text
      break if tool_uses.empty?

      used_tool = true
      messages << { role: "assistant", content: assistant_blocks(round_text, tool_uses) }
      messages << { role: "user", content: tool_uses.map { |tu| { tool_result: { tool_use_id: tu[:id], content: [{ json: call_tool(tools, tu) }] } } } }
    end
    @timings["llm_total_ms"] = ms_since(llm_started)
    @conversation.update_columns(tool_called: true) if used_tool
    [answer.strip, used_tool]
  end

  def assistant_blocks(text, tool_uses)
    blocks = text.strip.empty? ? [] : [{ text: text }]
    blocks + tool_uses.map { |tu| { tool_use: { tool_use_id: tu[:id], name: tu[:name], input: tu[:input] } } }
  end

  def call_tool(tools, tool_use)
    tool = tools.find { |t| t.name == tool_use[:name] }
    started = now
    output = Telemetry.span("tool.call", tool: tool_use[:name]) { tool ? ToolInvoker.new.call(tool, tool_use[:input]) : { "error" => "unknown_tool" } }
    @adapter.on_tool(tool_use[:name], tool_use[:input], output)
    @conversation.messages.create!(
      role: "tool", content: "#{tool_use[:name]}(#{tool_use[:input].values.join(', ')})",
      metadata: { "name" => tool_use[:name], "input" => tool_use[:input], "output" => output, "ms" => ms_since(started) }
    )
    output
  end

  def history
    @conversation.messages.where(role: %w[customer ai operator]).order(created_at: :desc).limit(9).to_a.reverse[0...-1].map do |m|
      { role: m.from_customer? ? "user" : "assistant", content: [{ text: m.content }] }
    end.then { |h| h.drop_while { |m| m[:role] == "assistant" } }
  end

  def citations_for(chunks)
    chunks.each_with_index.map do |c, i|
      src = c.knowledge_source
      { "n" => i + 1, "source_id" => src.id, "title" => src.title, "url" => help_url(src), "snippet" => c.content.truncate(120) }
    end
  end

  def help_url(source) = "#{ENV.fetch('HELP_CENTER_URL', 'http://localhost:3001')}/#{@company.slug}/help/#{source.id}"

  def reply_from_cache(cached)
    @timings["cache_hit"] = true
    @timings["end_to_end_ms"] = ms_since(@t0) unless @adapter.speaks?
    Llm.pieces(cached["text"]).each { |p| @adapter.on_token(@run_id, p) }
    persist_ai_message(cached["text"], cached["citations"])
  end

  def persist_ai_message(answer, citations)
    @adapter.finish
    @timings["tts_first_audio_ms"] = @adapter.first_audio_ms(@t0) if @adapter.speaks?
    @timings["end_to_end_ms"] ||= @timings["tts_first_audio_ms"]
    @timings["total_ms"] = ms_since(@t0)
    @timings.each { |stage, v| Telemetry.timing(stage, v, @conversation.channel) if v.is_a?(Numeric) }
    @conversation.messages.create!(role: "ai", content: answer, citations:, timings: @timings,
                                   metadata: { "run_id" => @run_id, "model" => (Llm.provider.last_model if Llm.provider.respond_to?(:last_model)) }.compact)
  end

  def escalate(reason, text)
    draft = draft_text(text)
    @conversation.escalate!(reason, draft:) # status flip and AI draft land in one update
    @conversation.messages.create!(role: "ai", content: Escalation.handoff_message(@locale), metadata: { "handoff" => reason, "run_id" => @run_id })
    ConversationChannel.broadcast_ops(@conversation, { type: "draft", draft: draft })
  end

  # While a human is handling the conversation the AI only prepares an editable draft for the operator.
  def draft_for_operator(text)
    draft = draft_text(text)
    @conversation.update_columns(draft_reply: draft)
    ConversationChannel.broadcast_ops(@conversation, { type: "draft", draft: draft })
  end

  def draft_text(text)
    chunks = Retriever.new.call(text).chunks.first(2)
    out = +""
    Llm.provider.stream(system: SystemPrompt.build(@company, @locale || @company.locale, chunks),
                        messages: [{ role: "user", content: [{ text: text }] }], tools: [],
                        context: chunks.map { |c| { text: c.content } }, locale: @locale || @company.locale) do |e|
      out << e[:text] if e[:type] == :token
    end
    out.strip
  end

  def intake_turn(text)
    flow = IntakeFlow.new(@conversation, @locale)
    reply = flow.advance(text)
    reply.each_char.each_slice(3) { |s| @adapter.on_token(@run_id, s.join) }
    persist_ai_message(reply, [])
  end
end
