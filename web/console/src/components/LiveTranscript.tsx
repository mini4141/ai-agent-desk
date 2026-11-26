import { useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import type { ConversationDetail, Message } from "../api";
import { subscribe } from "../cable";
import { useI18n } from "../i18n";

interface Props {
  conversationId: number;
  messages: Message[];
  onDraft: (draft: string) => void;
}

// Live transcript: merges Action Cable events into the TanStack Query cache so the page,
// the inbox and any other consumer of ["conversation", id] stay consistent.
export function LiveTranscript({ conversationId, messages, onDraft }: Props) {
  const { t } = useI18n();
  const qc = useQueryClient();
  const [streaming, setStreaming] = useState<Record<string, string>>({});

  useEffect(() => {
    const key = ["conversation", conversationId];
    return subscribe("ConversationChannel", { id: conversationId }, (ev) => {
      if (ev.type === "message") {
        const incoming: Message = ev.message;
        setStreaming((s) => (incoming.metadata?.run_id ? Object.fromEntries(Object.entries(s).filter(([k]) => k !== incoming.metadata.run_id)) : s));
        qc.setQueryData<ConversationDetail>(key, (old) => {
          if (!old || old.messages.some((m) => m.id === incoming.id)) return old;
          // Replace the optimistic copy of an operator message once the server confirms it.
          const optimistic = old.messages.findIndex((m) => String(m.id).startsWith("tmp-") && m.content === incoming.content);
          const next = optimistic >= 0 ? old.messages.map((m, i) => (i === optimistic ? incoming : m)) : [...old.messages, incoming];
          return { ...old, messages: next };
        });
      } else if (ev.type === "token") {
        setStreaming((s) => ({ ...s, [ev.run_id]: (s[ev.run_id] ?? "") + ev.text }));
      } else if (ev.type === "draft") {
        onDraft(ev.draft);
      } else if (ev.type === "history") {
        if (ev.draft) onDraft(ev.draft); // subscribed after the AI draft was written
      } else if (ev.type === "status") {
        void qc.invalidateQueries({ queryKey: key });
      }
    });
  }, [conversationId, qc, onDraft]);

  return (
    <div className="transcript" data-testid="transcript">
      {messages.map((m) => (
        <div key={m.id} className={`msg ${m.role}`} data-testid={`msg-${m.role}`}>
          {m.role === "tool" ? (
            <details>
              <summary>🔧 {t("toolCall")}: {m.content}</summary>
              <pre>{JSON.stringify(m.metadata, null, 2)}</pre>
            </details>
          ) : (
            <>
              <small>{m.role}</small>
              <p>{m.content}</p>
              {m.citations?.length > 0 && <small>{m.citations.map((c) => `[${c.n}] ${c.title}`).join(" · ")}</small>}
            </>
          )}
        </div>
      ))}
      {Object.entries(streaming).map(([run, text]) => <div key={run} className="msg ai streaming" data-testid="msg-streaming"><small>ai …</small><p>{text}</p></div>)}
    </div>
  );
}
