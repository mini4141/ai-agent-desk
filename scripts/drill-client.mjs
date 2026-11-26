// Chat client for the reliability drill (scripts/drill-kill-web-task.sh).
// Asks a question, waits for the web tier to be killed underneath it, reconnects like the widget's
// Action Cable client does, and proves the conversation (history + new answer) survived.
// Usage: node scripts/drill-client.mjs <baseUrl> <publicKey>
const base = process.argv[2] ?? "http://localhost:3000";
const key = process.argv[3] ?? "pk_demo_mirai";
const t0 = Date.now();
const log = (m) => console.log(`[+${((Date.now() - t0) / 1000).toFixed(1)}s] ${m}`);
const identifier = JSON.stringify({ channel: "ConversationChannel" });

const session = await (await fetch(`${base}/widget/v1/sessions`, {
  method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ public_key: key, visitor_id: `drill-${Date.now()}` }),
})).json();
log(`session created, conversation ${session.conversation_id}`);

// One connection attempt: resolves with { history, answer } handlers; rejects on close.
function connect(question) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`${base.replace(/^http/, "ws")}/cable?token=${session.token}`, ["actioncable-v1-json"]);
    const state = { history: null, answer: null, ws };
    ws.onerror = () => {};
    ws.onclose = () => reject(Object.assign(new Error("closed"), { state }));
    ws.onopen = () => ws.send(JSON.stringify({ command: "subscribe", identifier }));
    ws.onmessage = (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.type === "confirm_subscription" && question) {
        ws.send(JSON.stringify({ command: "message", identifier, data: JSON.stringify({ action: "ask", text: question }) }));
      }
      const m = msg.message;
      if (m?.type === "history") state.history = m.messages;
      if (m?.type === "message" && m.message.role === "ai" && question) {
        state.answer = m.message.content;
        resolve(state);
      }
    };
    if (!question) setTimeout(() => (state.history ? resolve(state) : undefined), 0);
    const poll = setInterval(() => { if (!question && state.history) { clearInterval(poll); resolve(state); } }, 100);
  });
}

// 1. first question on the original connection
const first = await connect("返品はできますか？");
log(`answer 1 received: ${first.answer.slice(0, 40)}...`);
console.log("READY_FOR_KILL");

// 2. the web tier dies; the socket closes
await new Promise((resolve) => { first.ws.onclose = resolve; });
log("connection lost (web task stopped)");

// 3. reconnect loop with 1 s back-off, as Action Cable does
let resumed;
for (let attempt = 1; attempt <= 90 && !resumed; attempt++) {
  try {
    resumed = await connect(null);
  } catch {
    log(`reconnect attempt ${attempt} failed`);
    await new Promise((r) => setTimeout(r, 1000));
  }
}
if (!resumed) { log("FAILED: could not reconnect within 90 s"); process.exit(1); }
log(`reconnected; history replayed: ${resumed.history.length} messages`);
const survived = resumed.history.some((m) => m.role === "ai" && m.content === first.answer);
log(survived ? "OK: earlier answer is still in the conversation" : "FAILED: history lost");
resumed.ws.onclose = () => {};
resumed.ws.close();

// 4. the conversation continues on the new connection
const second = await connect("配送料はいくらですか？");
log(`answer 2 received after recovery: ${second.answer.slice(0, 40)}...`);
second.ws.onclose = () => {};
second.ws.close();
log(survived ? "DRILL PASSED" : "DRILL FAILED");
process.exit(survived ? 0 : 1);
