import { createRoot } from "react-dom/client";
import styles from "./styles.css?inline";
import { initTelemetry } from "./telemetry";
import type { Channel, WidgetOptions } from "./types";
import { Widget } from "./Widget";

// Embed with:
//   <script src="https://<api>/widget.js" data-key="pk_..." data-channels="web_chat,voice_web,avatar"></script>
// The widget lives in a Shadow DOM so host-page CSS cannot leak in or out.
function mount(options: WidgetOptions) {
  initTelemetry(options.otlp);
  const host = document.createElement("div");
  host.id = "agent-desk-widget";
  document.body.appendChild(host);
  const shadow = host.attachShadow({ mode: "open" });
  const style = document.createElement("style");
  style.textContent = styles;
  shadow.appendChild(style);
  const container = document.createElement("div");
  shadow.appendChild(container);
  createRoot(container).render(<Widget {...options} />);
}

const script = document.currentScript as HTMLScriptElement | null;
if (script?.dataset.key) {
  const api = script.dataset.api ?? new URL(script.src).origin;
  mount({
    api,
    publicKey: script.dataset.key,
    channels: (script.dataset.channels ?? "web_chat").split(",") as Channel[],
    otlp: script.dataset.otlp,
    open: script.dataset.open === "true",
  });
}

(window as unknown as { AgentDesk: { mount: typeof mount } }).AgentDesk = { mount };
