import { useEffect, useMemo, useRef, useState } from "react";
import { Avatar } from "./Avatar";
import { browserLocale, t, type Locale } from "./i18n";
import type { Channel, ChatMessage, WidgetOptions } from "./types";
import { useConversation } from "./useConversation";
import { PushToTalk, SpeechPlayer, type SpeakEvent } from "./voice";

const LANG: Record<Locale, string> = { ja: "ja-JP", en: "en-US" };

export function Widget({ api, publicKey, channels, open: initialOpen }: WidgetOptions) {
  const [open, setOpen] = useState(initialOpen ?? false);
  const [channel, setChannel] = useState<Channel>(channels[0]);
  const [interview, setInterview] = useState(false);
  const [viseme, setViseme] = useState<string | null>(null);
  const [speaking, setSpeaking] = useState(false);
  const [spoken, setSpoken] = useState<string[]>([]);
  const [recording, setRecording] = useState(false);
  const [draft, setDraft] = useState("");
  const [locale, setLocale] = useState<Locale>(browserLocale());
  const ptt = useRef(new PushToTalk());
  const listRef = useRef<HTMLDivElement>(null);
  const localeRef = useRef(locale);
  localeRef.current = locale;

  const player = useMemo(
    () => new SpeechPlayer(() => LANG[localeRef.current], setViseme, (s, list) => { setSpeaking(s); setSpoken(list); }),
    [],
  );
  const mode = interview ? "interview" : "chat";
  const convo = useConversation({
    api, publicKey, channel, mode,
    onSpeak: (ev: SpeakEvent) => (channel === "web_chat" ? undefined : player.enqueue(ev)),
  });
  const { session } = convo;
  useEffect(() => { if (session) setLocale(session.company.locale); }, [session]);
  useEffect(() => { listRef.current?.scrollTo({ top: listRef.current.scrollHeight }); }, [convo.messages]);
  useEffect(() => { player.reset(); }, [channel, interview, player]);

  const tr = t(locale);
  const send = () => { convo.ask(draft); setDraft(""); };
  const showSuggestions = session && session.suggestions.length > 0 && convo.messages.filter((m) => m.role === "customer").length === 0;

  const startTalking = async () => {
    setRecording(true);
    convo.audioStart(LANG[locale]);
    await ptt.current.start(convo.sendAudio, LANG[locale]);
  };
  const stopTalking = async () => {
    if (!recording) return;
    setRecording(false);
    const { total, hint } = await ptt.current.stop();
    convo.audioEnd(total, hint, locale);
  };

  if (!open) {
    return <button className="launcher" data-testid="launcher" onClick={() => setOpen(true)} aria-label={tr.title}>💬</button>;
  }

  return (
    <section className="panel" data-testid="widget" data-status={convo.status} data-variant={session?.variant}>
      <header>
        <strong>{session?.company.name ?? tr.title}</strong>
        <span className={`dot ${convo.connected ? "on" : ""}`} title={convo.connected ? "online" : "reconnecting"} />
        <button className="close" onClick={() => setOpen(false)} aria-label="close">×</button>
      </header>
      {channels.length > 1 && (
        <nav className="tabs">
          {channels.map((c) => (
            <button key={c} className={c === channel ? "active" : ""} data-testid={`tab-${c}`} onClick={() => { setChannel(c); setInterview(false); }}>
              {c === "web_chat" ? tr.chat : c === "voice_web" ? tr.voice : tr.avatar}
            </button>
          ))}
        </nav>
      )}

      {channel === "avatar" && (
        <div className="stage">
          <Avatar viseme={viseme} speaking={speaking} />
          <button className={`chip ${interview ? "active" : ""}`} data-testid="interview-toggle" onClick={() => setInterview((v) => !v)}>{tr.interview}</button>
        </div>
      )}

      <div className="messages" ref={listRef} data-testid="messages">
        {convo.messages.map((m) => <Bubble key={m.id} m={m} locale={locale} />)}
        {convo.partial && <div className="bubble customer partial">{convo.partial}</div>}
        {convo.status === "waiting_human" && <div className="notice" data-testid="waiting-human">{tr.waiting}</div>}
        {convo.status === "human" && <div className="notice" data-testid="human-joined">{tr.human}</div>}
      </div>

      {showSuggestions && (
        <div className="suggestions" data-testid="suggestions">
          {session.suggestions.map((s) => <button key={s} onClick={() => convo.ask(s)}>{s}</button>)}
        </div>
      )}

      {channel !== "web_chat" && (
        <div className="voice-bar">
          <button
            className={`ptt ${recording ? "rec" : ""}`} data-testid="ptt" disabled={!convo.voiceReady}
            onPointerDown={() => void startTalking()} onPointerUp={() => void stopTalking()} onPointerLeave={() => void stopTalking()}
          >
            {recording ? tr.listening : speaking ? tr.speaking : tr.hold}
          </button>
          <div className="spoken" data-testid="spoken" data-count={spoken.length} data-all={spoken.join("")}>{spoken.at(-1)}</div>
        </div>
      )}

      <form className="composer" onSubmit={(e) => { e.preventDefault(); send(); }}>
        <input data-testid="input" value={draft} onChange={(e) => setDraft(e.target.value)} placeholder={tr.placeholder} />
        <button type="submit" data-testid="send">{tr.send}</button>
      </form>

      <footer className="csat">
        {convo.csatDone ? <span data-testid="csat-thanks">{tr.thanks}</span> : (
          <>
            <button data-testid="csat-up" onClick={() => void convo.csat("up")}>👍 {tr.helpful}</button>
            <button data-testid="csat-down" onClick={() => void convo.csat("down")}>👎 {tr.notHelpful}</button>
          </>
        )}
      </footer>
    </section>
  );
}

function Bubble({ m, locale }: { m: ChatMessage; locale: Locale }) {
  const tr = t(locale);
  if (m.role === "tool") return <div className="tool-chip" data-testid="tool-chip">🔧 {tr.tool}: {m.content}</div>;
  return (
    <div className={`bubble ${m.role}`} data-testid={`bubble-${m.role}`}>
      {m.role === "operator" && <small>{String(m.metadata?.operator ?? "")}</small>}
      <span>{m.content}</span>
      {!!m.citations?.length && (
        <div className="citations" data-testid="citations">
          {tr.sources}: {m.citations.map((c) => <a key={c.n} href={c.url} target="_blank" rel="noreferrer">[{c.n}] {c.title}</a>)}
        </div>
      )}
    </div>
  );
}
