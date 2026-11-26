import { createConsumer, type Subscription } from "@rails/actioncable";
import { useCallback, useEffect, useRef, useState } from "react";
import { startSpan } from "./telemetry";
import type { Channel, ChatMessage, Session } from "./types";
import type { SpeakEvent } from "./voice";

interface Options {
  api: string;
  publicKey: string;
  channel: Channel;
  mode: "chat" | "interview";
  onSpeak?: (ev: SpeakEvent) => void;
}

type ServerEvent = {
  type: string;
  [k: string]: any; // eslint-disable-line @typescript-eslint/no-explicit-any
};

// crypto.randomUUID only exists in secure contexts (https / localhost); plain-http embeds fall back to getRandomValues.
const uuid = () =>
  typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : "10000000-1000-4000-8000-100000000000".replace(/[018]/g, (c) => (Number(c) ^ (crypto.getRandomValues(new Uint8Array(1))[0] & (15 >> (Number(c) / 4)))).toString(16));

const visitorId = () => {
  const key = "agent-desk-visitor";
  let id = localStorage.getItem(key);
  if (!id) localStorage.setItem(key, (id = uuid()));
  return id;
};

const toMessage = (m: any): ChatMessage => ({ // eslint-disable-line @typescript-eslint/no-explicit-any
  id: m.id, role: m.role, content: m.content, citations: m.citations, metadata: m.metadata, runId: m.metadata?.run_id,
});

// Session + Action Cable subscription for one conversation: streams tokens, applies final messages,
// and resumes from `history` after Action Cable reconnects (so a killed web task never loses the chat).
export function useConversation({ api, publicKey, channel, mode, onSpeak }: Options) {
  const [session, setSession] = useState<Session | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [status, setStatus] = useState("ai");
  const [connected, setConnected] = useState(false);
  const [partial, setPartial] = useState("");
  const [csatDone, setCsatDone] = useState(false);
  const [voiceReady, setVoiceReady] = useState(false);
  const conv = useRef<Subscription | null>(null);
  const voice = useRef<Subscription | null>(null);
  const speakRef = useRef(onSpeak);
  speakRef.current = onSpeak;

  useEffect(() => {
    let consumer: ReturnType<typeof createConsumer> | undefined;
    let cancelled = false;
    setSession(null);
    setConnected(false);
    setVoiceReady(false);
    setMessages([]);
    setStatus("ai");
    setCsatDone(false);

    const span = startSpan("widget.session.create");
    fetch(`${api}/widget/v1/sessions`, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...(span.traceparent ? { traceparent: span.traceparent } : {}) },
      body: JSON.stringify({ public_key: publicKey, channel, mode, visitor_id: visitorId() }),
    })
      .then((r) => r.json() as Promise<Session>)
      .then((s) => {
        span.end();
        if (cancelled) return;
        setSession(s);
        const opener = mode === "interview" ? s.opening : s.greeting;
        if (opener) setMessages([{ id: "greeting", role: "ai", content: opener }]);
        if (mode === "interview" && s.opening) speakRef.current?.({ seq: 1, text: s.opening, audio: null, mime: null, visemes: [] });
        consumer = createConsumer(`${api.replace(/^http/, "ws")}/cable?token=${s.token}`);
        conv.current = consumer.subscriptions.create("ConversationChannel", {
          connected: () => setConnected(true),
          disconnected: () => setConnected(false),
          received: (ev: ServerEvent) => apply(ev),
        });
        if (channel !== "web_chat") voice.current = consumer.subscriptions.create("VoiceChannel", { connected: () => setVoiceReady(true), disconnected: () => setVoiceReady(false) });
      });

    const apply = (ev: ServerEvent) => {
      switch (ev.type) {
        case "history":
          setStatus(ev.status);
          setMessages((prev) => {
            const greeting = prev.filter((m) => m.id === "greeting");
            return [...greeting, ...ev.messages.filter((m: any) => m.role !== "tool").map(toMessage)]; // eslint-disable-line @typescript-eslint/no-explicit-any
          });
          break;
        case "token":
          setMessages((prev) => {
            const idx = prev.findIndex((m) => m.runId === ev.run_id && m.streaming);
            if (idx >= 0) return prev.map((m, i) => (i === idx ? { ...m, content: m.content + ev.text } : m));
            return [...prev, { id: `run-${ev.run_id}`, role: "ai", content: ev.text, runId: ev.run_id, streaming: true }];
          });
          break;
        case "tool":
          setMessages((prev) => [...prev, { id: `tool-${Date.now()}`, role: "tool", content: ev.name, metadata: { ok: ev.ok } }]);
          break;
        case "message":
          applyMessage(toMessage(ev.message));
          break;
        case "status":
          setStatus(ev.status);
          break;
        case "transcript":
          setPartial(ev.final ? "" : ev.text);
          break;
        case "speak":
          speakRef.current?.(ev as unknown as SpeakEvent);
          break;
      }
    };

    const applyMessage = (m: ChatMessage) => {
      if (m.role === "tool") return; // the live "tool" event already rendered the chip
      setMessages((prev) => {
        if (prev.some((x) => x.id === m.id)) return prev;
        if (m.role === "customer") {
          const local = prev.findIndex((x) => typeof x.id === "string" && String(x.id).startsWith("local-") && x.content === m.content);
          if (local >= 0) return prev.map((x, i) => (i === local ? m : x));
        }
        const streamed = m.runId ? prev.findIndex((x) => x.runId === m.runId && x.streaming) : -1;
        if (streamed >= 0) return prev.map((x, i) => (i === streamed ? m : x));
        return [...prev, m];
      });
    };

    return () => {
      cancelled = true;
      consumer?.disconnect();
    };
  }, [api, publicKey, channel, mode]);

  const ask = useCallback((text: string) => {
    if (!text.trim()) return;
    const span = startSpan("widget.ask");
    setMessages((prev) => [...prev, { id: `local-${Date.now()}`, role: "customer", content: text }]);
    conv.current?.perform("ask", { text, traceparent: span.traceparent });
    span.end();
  }, []);

  const sendAudio = useCallback((seq: number, pcm: string) => voice.current?.perform("audio", { seq, pcm }), []);
  const audioStart = useCallback((lang: string) => voice.current?.perform("audio_start", { lang }), []);
  const audioEnd = useCallback((total: number, hint: string | undefined, lang: string) => {
    const span = startSpan("widget.voice.utterance");
    voice.current?.perform("audio_end", { total, hint, lang, traceparent: span.traceparent });
    span.end();
  }, []);

  const csat = useCallback(async (score: "up" | "down") => {
    if (!session) return;
    await fetch(`${api}/widget/v1/conversations/${session.conversation_id}/csat`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${session.token}` },
      body: JSON.stringify({ score }),
    });
    setCsatDone(true);
  }, [api, session]);

  return { session, messages, status, connected, voiceReady, partial, csatDone, ask, sendAudio, audioStart, audioEnd, csat };
}
