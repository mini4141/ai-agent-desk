import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { api, type ConversationDetail, type Message } from "../api";
import { LiveTranscript } from "../components/LiveTranscript";
import { useI18n } from "../i18n";

export function ConversationView() {
  const { id } = useParams();
  const conversationId = Number(id);
  const { t } = useI18n();
  const qc = useQueryClient();
  const key = ["conversation", conversationId];
  const [draft, setDraft] = useState("");
  const [tags, setTags] = useState("");

  const { data } = useQuery({ queryKey: key, queryFn: () => api<ConversationDetail>(`/api/v1/conversations/${conversationId}`) });
  const onDraft = useCallback((d: string) => setDraft(d), []);
  useEffect(() => { if (data?.draft_reply) setDraft((cur) => cur || data.draft_reply!); }, [data?.draft_reply]);
  useEffect(() => { if (data) setTags(data.tags.join(", ")); }, [data?.tags]);

  const refresh = () => { void qc.invalidateQueries({ queryKey: key }); void qc.invalidateQueries({ queryKey: ["conversations"] }); };

  // Optimistic update: the operator reply shows up immediately and rolls back if the request fails.
  const send = useMutation({
    mutationFn: (content: string) => api<Message>(`/api/v1/conversations/${conversationId}/messages`, { method: "POST", body: { content } }),
    onMutate: async (content) => {
      await qc.cancelQueries({ queryKey: key });
      const previous = qc.getQueryData<ConversationDetail>(key);
      const temp: Message = { id: `tmp-${Date.now()}`, role: "operator", content, citations: [], metadata: {}, timings: {}, created_at: new Date().toISOString() };
      qc.setQueryData<ConversationDetail>(key, (old) => (old ? { ...old, messages: [...old.messages, temp] } : old));
      setDraft("");
      return { previous };
    },
    onError: (_e, _c, ctx) => ctx?.previous && qc.setQueryData(key, ctx.previous),
    onSettled: refresh,
  });
  const action = useMutation({ mutationFn: (name: "assign" | "handback" | "resolve") => api(`/api/v1/conversations/${conversationId}/${name}`, { method: "POST" }), onSettled: refresh });
  const saveTags = useMutation({
    mutationFn: () => api(`/api/v1/conversations/${conversationId}/tags`, { method: "PATCH", body: { tags: tags.split(",").map((s) => s.trim()).filter(Boolean) } }),
    onSettled: refresh,
  });

  if (!data) return <p>…</p>;
  const answers = data.intake?.answers;
  return (
    <section className="conversation">
      <div className="row">
        <h2>#{data.id}</h2>
        <span className={`badge ${data.status}`} data-testid="status">{data.status}</span>
        <span className="badge">{data.channel}</span>
        {data.escalation_reason && <span className="badge warn">{data.escalation_reason}</span>}
      </div>
      <div className="split">
        <LiveTranscript conversationId={conversationId} messages={data.messages} onDraft={onDraft} />
        <aside className="controls">
          <label>{t("draft")}
            <textarea data-testid="draft" value={draft} onChange={(e) => setDraft(e.target.value)} rows={6} />
          </label>
          <button data-testid="send" disabled={!draft.trim() || data.status === "resolved"} onClick={() => send.mutate(draft)}>{t("sendDraft")}</button>
          <div className="buttons">
            <button data-testid="take-over" onClick={() => action.mutate("assign")} disabled={data.status === "human" || data.status === "resolved"}>{t("takeOver")}</button>
            <button data-testid="hand-back" onClick={() => action.mutate("handback")} disabled={data.status === "ai" || data.status === "resolved"}>{t("handBack")}</button>
            <button data-testid="resolve" onClick={() => action.mutate("resolve")} disabled={data.status === "resolved"}>{t("resolve")}</button>
          </div>
          <label>{t("tags")}
            <input value={tags} onChange={(e) => setTags(e.target.value)} onBlur={() => saveTags.mutate()} />
          </label>
          {answers && (
            <div data-testid="intake">
              <h4>{t("intake")}</h4>
              <ul>{Object.entries(answers).map(([k, v]) => <li key={k}><b>{k}</b>: {v}</li>)}</ul>
            </div>
          )}
        </aside>
      </div>
    </section>
  );
}
