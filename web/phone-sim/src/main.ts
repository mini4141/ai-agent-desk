import { createConsumer, type Subscription } from "@rails/actioncable";
import { decodeSample, encodeSample } from "./mulaw";

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
if (import.meta.env.VITE_API_URL === "same-origin") $<HTMLInputElement>("api").value = window.location.origin;
const log = (text: string) => {
  const li = document.createElement("li");
  li.textContent = text;
  $("log").appendChild(li);
};
const setState = (s: string) => {
  $("state").textContent = s;
  $("state").dataset.state = s;
};

let sub: Subscription | undefined;
let streamSid = "";
let seq = 0;
let playCtx: AudioContext | undefined;
let playHead = 0;
let sources: AudioBufferSourceNode[] = [];
let mic: { stop: () => void } | undefined;

function playUlaw(b64: string) {
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  playCtx ??= new AudioContext({ sampleRate: 8000 });
  const buffer = playCtx.createBuffer(1, bytes.length, 8000);
  const data = buffer.getChannelData(0);
  bytes.forEach((b, i) => (data[i] = decodeSample(b) / 32768));
  const src = playCtx.createBufferSource();
  src.buffer = buffer;
  src.connect(playCtx.destination);
  playHead = Math.max(playHead, playCtx.currentTime);
  src.start(playHead);
  playHead += buffer.duration;
  sources.push(src);
  setState("agent-speaking");
  src.onended = () => {
    sources = sources.filter((s) => s !== src);
    if (sources.length === 0) setState("in-call");
  };
}

function stopPlayback() {
  sources.forEach((s) => s.stop());
  sources = [];
  playHead = 0;
}

async function startCall() {
  const api = $<HTMLInputElement>("api").value;
  const res = await fetch(`${api}/widget/v1/sessions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ public_key: $<HTMLInputElement>("key").value, channel: "phone_sim", visitor_id: `phone-${Date.now()}` }),
  });
  const session = await res.json();
  streamSid = `MZ${session.conversation_id}`;
  const consumer = createConsumer(`${api.replace(/^http/, "ws")}/phone-sim/stream?token=${session.token}`);
  sub = consumer.subscriptions.create("PhoneStreamChannel", {
    connected: () => {
      sub?.perform("event", { event: "start", start: { streamSid, callSid: `CA${session.conversation_id}` } });
      log(`call connected (conversation ${session.conversation_id})`);
      setState("in-call");
      $<HTMLButtonElement>("talk").disabled = false;
      $<HTMLButtonElement>("hangup").disabled = false;
    },
    received: (ev: { event?: string; type?: string; text?: string; media?: { payload: string } }) => {
      if (ev.event === "media" && ev.media) playUlaw(ev.media.payload);
      else if (ev.event === "clear") {
        stopPlayback();
        log("barge-in: agent audio cleared");
        setState("barge-in");
      } else if (ev.type === "transcript" && ev.text) log(`agent: ${ev.text}`);
      else if (ev.type === "message" && (ev as { message?: { role: string; content: string } }).message?.role === "customer") {
        log(`caller: ${(ev as { message: { content: string } }).message.content}`);
      }
    },
  });
  $<HTMLButtonElement>("call").disabled = true;
}

// Push-to-talk: capture mic, downsample to 8 kHz, mu-law encode, and send telephony-style media events.
async function startTalking() {
  seq = 0;
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  const ctx = new AudioContext();
  const node = ctx.createScriptProcessor(4096, 1, 1);
  const ratio = ctx.sampleRate / 8000;
  node.onaudioprocess = (e) => {
    const input = e.inputBuffer.getChannelData(0);
    const out = new Uint8Array(Math.floor(input.length / ratio));
    for (let i = 0; i < out.length; i++) out[i] = encodeSample(Math.max(-1, Math.min(1, input[Math.floor(i * ratio)])) * 32767);
    let bin = "";
    out.forEach((b) => (bin += String.fromCharCode(b)));
    sub?.perform("event", { event: "media", streamSid, sequenceNumber: seq++, media: { track: "inbound", payload: btoa(bin) } });
  };
  const source = ctx.createMediaStreamSource(stream);
  source.connect(node);
  node.connect(ctx.destination);
  mic = { stop: () => { node.disconnect(); stream.getTracks().forEach((t) => t.stop()); void ctx.close(); } };
}

function stopTalking() {
  if (!mic) return;
  mic.stop();
  mic = undefined;
  sub?.perform("event", { event: "mark", streamSid, mark: { name: "utterance_end", total: seq, hint: $<HTMLInputElement>("hint").value } });
  log("caller finished speaking");
}

$("call").addEventListener("click", () => void startCall());
$("talk").addEventListener("pointerdown", () => void startTalking());
$("talk").addEventListener("pointerup", stopTalking);
$("hangup").addEventListener("click", () => {
  sub?.perform("event", { event: "stop", streamSid });
  sub?.unsubscribe();
  stopPlayback();
  setState("idle");
  log("call ended");
  $<HTMLButtonElement>("call").disabled = false;
  $<HTMLButtonElement>("talk").disabled = true;
  $<HTMLButtonElement>("hangup").disabled = true;
});
