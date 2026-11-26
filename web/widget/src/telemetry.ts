import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { resourceFromAttributes } from "@opentelemetry/resources";
import { BatchSpanProcessor } from "@opentelemetry/sdk-trace-base";
import { WebTracerProvider } from "@opentelemetry/sdk-trace-web";

// Browser tracing: spans for session creation and each question, with a W3C traceparent that
// the Rails side continues (widget -> Rails -> Sidekiq -> Bedrock shows up as one trace).
export interface ActiveSpan {
  traceparent: string | undefined;
  end: () => void;
}

let provider: WebTracerProvider | undefined;

export function initTelemetry(otlpUrl?: string) {
  if (!otlpUrl || provider) return;
  provider = new WebTracerProvider({
    resource: resourceFromAttributes({ "service.name": "agent-desk-widget" }),
    spanProcessors: [new BatchSpanProcessor(new OTLPTraceExporter({ url: otlpUrl }))],
  });
  provider.register();
}

export function startSpan(name: string): ActiveSpan {
  if (!provider) return { traceparent: undefined, end: () => {} };
  const span = provider.getTracer("agent-desk-widget").startSpan(name);
  const { traceId, spanId } = span.spanContext();
  return { traceparent: `00-${traceId}-${spanId}-01`, end: () => span.end() };
}
