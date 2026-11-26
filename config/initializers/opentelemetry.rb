# Distributed tracing: widget -> Rails -> Sidekiq -> Bedrock. The exporter endpoint comes from
# OTEL_EXPORTER_OTLP_ENDPOINT (Jaeger via the collector locally, ADOT sidecar -> X-Ray in AWS).
if ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present? && !Rails.env.test?
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/instrumentation/all"

  OpenTelemetry::SDK.configure do |c|
    c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "agent-desk-rails")
    c.use_all("OpenTelemetry::Instrumentation::Rack" => { untraced_endpoints: ["/up", "/metrics"] })
  end
end
