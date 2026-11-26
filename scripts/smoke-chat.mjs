// Smoke test: open a widget session, ask a question over Action Cable, print the streamed events.
// Usage: node scripts/smoke-chat.mjs [baseUrl] [publicKey] [question]
const base = process.argv[2] ?? "http://localhost:3000";
const key = process.argv[3] ?? "pk_demo_mirai";
const question = process.argv[4] ?? "注文 A-1023 はいつ届きますか？";

const res = await fetch(`${base}/widget/v1/sessions`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ public_key: key, channel: "web_chat", visitor_id: `smoke-${Date.now()}` }),
});
if (!res.ok) throw new Error(`session failed: ${res.status} ${await res.text()}`);
const session = await res.json();

const ws = new WebSocket(`${base.replace(/^http/, "ws")}/cable?token=${session.token}`, ["actioncable-v1-json"]);
const identifier = JSON.stringify({ channel: "ConversationChannel" });
const t0 = performance.now();
let first = null;
let answer = "";

await new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error("timeout waiting for answer")), 20000);
  ws.onerror = (e) => reject(new Error(`ws error ${e.message ?? ""}`));
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.type === "confirm_subscription") {
      ws.send(JSON.stringify({ command: "message", identifier, data: JSON.stringify({ action: "ask", text: question }) }));
    }
    const m = msg.message;
    if (!m) return;
    if (m.type === "token") {
      first ??= performance.now() - t0;
      answer += m.text;
    }
    if (m.type === "tool") console.log("tool:", m.name, "ok=", m.ok);
    if (m.type === "message" && m.message.role === "ai") {
      clearTimeout(timer);
      console.log("answer:", m.message.content);
      console.log("citations:", JSON.stringify(m.message.citations.map((c) => c.url)));
      console.log("timings:", JSON.stringify(m.message.timings));
      resolve();
    }
  };
  ws.onopen = () => ws.send(JSON.stringify({ command: "subscribe", identifier }));
});
console.log(`first token after ${Math.round(first ?? -1)} ms; streamed ${answer.length} chars`);
ws.close();
