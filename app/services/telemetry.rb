# One place for traces, Prometheus metrics (local) and CloudWatch EMF lines (AWS).
module Telemetry
  BUCKETS = [5, 10, 25, 50, 100, 250, 500, 1000, 1500, 2500, 5000].freeze
  REGISTRY = Prometheus::Client.registry

  STAGE_MS = REGISTRY.get(:agent_stage_ms) ||
    REGISTRY.histogram(:agent_stage_ms, docstring: "Per-turn stage latency", labels: %i[stage channel], buckets: BUCKETS)
  CACHE = REGISTRY.get(:agent_answer_cache_total) ||
    REGISTRY.counter(:agent_answer_cache_total, docstring: "Answer cache lookups", labels: [:result])
  HANDOFFS = REGISTRY.get(:agent_handoffs_total) ||
    REGISTRY.counter(:agent_handoffs_total, docstring: "Human handoffs", labels: [:reason])

  module_function

  def tracer
    OpenTelemetry.tracer_provider.tracer("agent-desk")
  end

  def span(name, attrs = {}, &block)
    clean = attrs.to_h { |k, v| [k.to_s, v.is_a?(String) ? PiiRedactor.redact(v) : v] }
    tracer.in_span(name, attributes: clean, &block)
  end

  def timing(stage, ms, channel)
    STAGE_MS.observe(ms, labels: { stage: stage.to_s, channel: channel.to_s })
    emf("Latency", stage.to_s => ms, dims: { Channel: channel.to_s }) if ENV["EMF"] == "1"
  end

  def cache(result)
    CACHE.increment(labels: { result: result.to_s })
  end

  def handoff(reason)
    HANDOFFS.increment(labels: { reason: reason.to_s })
  end

  # CloudWatch Embedded Metric Format: a JSON log line becomes a custom metric.
  def emf(namespace_suffix, values, dims: {})
    metrics = values.reject { |k, _| k == :dims }
    line = {
      _aws: {
        Timestamp: (Time.now.to_f * 1000).to_i,
        CloudWatchMetrics: [{
          Namespace: "AgentDesk/#{namespace_suffix}",
          Dimensions: [dims.keys.map(&:to_s)],
          Metrics: metrics.keys.map { |k| { Name: k.to_s, Unit: k.to_s.end_with?("_ms") ? "Milliseconds" : "Count" } }
        }]
      }
    }.merge(dims.transform_keys(&:to_s)).merge(metrics.transform_keys(&:to_s))
    $stdout.puts(line.to_json)
  end
end
