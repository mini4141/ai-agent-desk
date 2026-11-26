// k6 latency smoke: time-to-first-token (TTFT) of the streaming chat path over Action Cable.
//   k6 run -e BASE_URL=http://localhost:3000 -e DURATION=2m -e VUS=20 scripts/k6-chat.js
// Each virtual user is one chatting customer: one widget session + one WebSocket, asking a new question
// every 1-2 s. Budget: local mock LLM p95 TTFT < 400 ms (SPECS F8); cloud runs relax it with -e TTFT_P95=1500.
import http from "k6/http";
import ws from "k6/ws";
import { check, sleep } from "k6";
import { Counter, Trend } from "k6/metrics";

const BASE = __ENV.BASE_URL || "http://localhost:3000";
const KEY = __ENV.PUBLIC_KEY || "pk_demo_mirai";
const WS_BASE = BASE.replace(/^http/, "ws");
const DURATION_S = Number(__ENV.DURATION_S || 120);
const ttft = new Trend("ttft_ms", true);
const total = new Trend("answer_total_ms", true);
const answered = new Counter("answers");

export const options = {
  scenarios: {
    chat: { executor: "per-vu-iterations", vus: Number(__ENV.VUS || 20), iterations: 1, maxDuration: `${DURATION_S + 30}s` },
  },
  thresholds: {
    ttft_ms: [`p(95)<${__ENV.TTFT_P95 || 400}`],
    checks: ["rate>0.99"],
  },
};

const QUESTIONS = ["返品はできますか？", "配送料はいくらですか？", "ポイントの有効期限は？", "支払い方法は？", "保証期間はどれくらい？"];

export default function () {
  const headers = { "Content-Type": "application/json", "X-Load-Test": __ENV.LOAD_TEST_TOKEN || "" };
  const res = http.post(`${BASE}/widget/v1/sessions`, JSON.stringify({ public_key: KEY, visitor_id: `k6-${__VU}-${Date.now()}` }), { headers });
  if (!check(res, { "session created": (r) => r.status === 201 })) return;
  const token = res.json("token");
  const identifier = JSON.stringify({ channel: "ConversationChannel" });
  const endAt = Date.now() + DURATION_S * 1000;
  let sentAt = 0;
  let gotFirst = false;

  ws.connect(`${WS_BASE}/cable?token=${token}`, { headers: { "Sec-WebSocket-Protocol": "actioncable-v1-json" } }, (socket) => {
    const ask = () => {
      if (Date.now() > endAt) return socket.close();
      // half the questions are unique (answer-cache miss), half repeat (cache hit)
      const base = QUESTIONS[Math.floor(Math.random() * QUESTIONS.length)];
      const question = Math.random() < 0.5 ? `${base} ${Math.floor(Math.random() * 1e6)}` : base;
      gotFirst = false;
      sentAt = Date.now();
      socket.send(JSON.stringify({ command: "message", identifier, data: JSON.stringify({ action: "ask", text: question }) }));
    };
    socket.on("open", () => socket.send(JSON.stringify({ command: "subscribe", identifier })));
    socket.on("message", (data) => {
      const msg = JSON.parse(data);
      if (msg.type === "confirm_subscription") ask();
      const m = msg.message;
      if (!m) return;
      if (m.type === "token" && !gotFirst) {
        gotFirst = true;
        ttft.add(Date.now() - sentAt);
      }
      if (m.type === "message" && m.message.role === "ai") {
        total.add(Date.now() - sentAt);
        answered.add(1);
        socket.setTimeout(ask, 1000 + Math.random() * 1000);
      }
    });
    socket.setTimeout(() => socket.close(), (DURATION_S + 20) * 1000);
  });
  sleep(1);
}

export function handleSummary(data) {
  const t = data.metrics.ttft_ms.values;
  const text = `TTFT ms  p50=${t.med.toFixed(0)} p90=${t["p(90)"].toFixed(0)} p95=${t["p(95)"].toFixed(0)} max=${t.max.toFixed(0)}  answers=${data.metrics.answers ? data.metrics.answers.values.count : 0}\n`;
  const out = { stdout: text };
  if (__ENV.SUMMARY_JSON) out[__ENV.SUMMARY_JSON] = JSON.stringify(data, null, 2);
  return out;
}
