# Distributed tracing: widget -> Rails -> Sidekiq -> Bedrock. The exporter endpoint comes from
# OTEL_EXPORTER_OTLP_ENDPOINT (Jaeger via the collector locally, ADOT sidecar -> X-Ray in AWS).
if ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present? && !Rails.env.test?
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/instrumentation/all"

  # AWS X-Ray only accepts trace ids whose first 4 bytes are the epoch seconds.
  module XrayIdGenerator
    def self.generate_trace_id = [Time.now.to_i].pack("N") + SecureRandom.random_bytes(12)
    def self.generate_span_id = SecureRandom.random_bytes(8)
  end

  OpenTelemetry::SDK.configure do |c|
    c.id_generator = XrayIdGenerator if ENV["OTEL_XRAY_IDS"] == "1"
    c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "agent-desk-rails")
    c.use_all("OpenTelemetry::Instrumentation::Rack" => { untraced_endpoints: ["/up", "/metrics"] })
  end
end
