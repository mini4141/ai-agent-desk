// Warms the Rails code paths (autoload, JIT, connections) so the first real user is not the one paying for them:
// chat answer, tool call, escalation + AI draft, and the voice audio path.
// Usage: node scripts/warmup.mjs [baseUrl] [publicKey]
const base = process.argv[2] ?? "http://localhost:3000";
const key = process.argv[3] ?? "pk_demo_mirai";
const identifier = JSON.stringify({ channel: "ConversationChannel" });
const voiceId = JSON.stringify({ channel: "VoiceChannel" });

async function run(channel, steps) {
  const session = await (await fetch(`${base}/widget/v1/sessions`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ public_key: key, channel, visitor_id: `smoke-warm-${Date.now()}` }),
  })).json();
  const ws = new WebSocket(`${base.replace(/^http/, "ws")}/cable?token=${session.token}`, ["actioncable-v1-json"]);
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("warmup timeout")), 60000);
    let step = 0;
    const send = (id, data) => ws.send(JSON.stringify({ command: "message", identifier: id, data: JSON.stringify(data) }));
    const next = () => {
      if (step >= steps.length) { clearTimeout(timer); return resolve(); }
      steps[step++](send);
    };
    ws.onopen = () => {
      ws.send(JSON.stringify({ command: "subscribe", identifier }));
      if (channel !== "web_chat") ws.send(JSON.stringify({ command: "subscribe", identifier: voiceId }));
    };
    let subscribed = 0;
    ws.onmessage = (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.type === "confirm_subscription" && ++subscribed === (channel === "web_chat" ? 1 : 2)) next();
      if (msg.message?.type === "message" && msg.message.message.role === "ai") next();
    };
  });
  ws.close();
}

const ask = (text) => (send) => send(identifier, { action: "ask", text });
await run("web_chat", [ask("注文 A-1023 はいつ届きますか？"), ask("返品はできますか？"), ask("人と話したいです")]);
await run("voice_web", [(send) => {
  send(voiceId, { action: "audio_start", lang: "ja-JP" });
  send(voiceId, { action: "audio", seq: 0, pcm: Buffer.alloc(3200).toString("base64") });
  send(voiceId, { action: "audio_end", total: 1, hint: "配送料はいくらですか？", lang: "ja" });
}]);
console.log("warm-up done");
