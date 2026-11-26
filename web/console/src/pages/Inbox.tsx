import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, type Conversation } from "../api";
import { subscribe } from "../cable";
import { useI18n } from "../i18n";

export function Inbox() {
  const { t } = useI18n();
  const qc = useQueryClient();
  const [view, setView] = useState<"open" | "resolved">("open");

  const { data, isLoading } = useQuery({
    queryKey: ["conversations", view],
    queryFn: () => api<{ conversations: Conversation[] }>(`/api/v1/conversations${view === "resolved" ? "?status=resolved" : ""}`),
  });

  // Live invalidation: any conversation change pushed by Action Cable refreshes the list.
  useEffect(() => subscribe("InboxChannel", {}, () => void qc.invalidateQueries({ queryKey: ["conversations"] })), [qc]);

  const rows = data?.conversations ?? [];
  return (
    <section>
      <div className="row">
        <h2>{t("inbox")}</h2>
        <span className="badge live">● {t("live")}</span>
        <div className="tabs">
          <button className={view === "open" ? "active" : ""} onClick={() => setView("open")}>{t("open")}</button>
          <button className={view === "resolved" ? "active" : ""} onClick={() => setView("resolved")}>{t("resolved")}</button>
        </div>
      </div>
      {isLoading ? <p>…</p> : rows.length === 0 ? <p>{t("noConversations")}</p> : (
        <table>
          <thead><tr><th>#</th><th>{t("status")}</th><th>{t("channel")}</th><th>{t("preview")}</th><th>{t("variant")}</th></tr></thead>
          <tbody>
            {rows.map((c) => (
              <tr key={c.id} data-testid="inbox-row" data-status={c.status}>
                <td><Link to={`/inbox/${c.id}`}>#{c.id}</Link></td>
                <td><span className={`badge ${c.status}`}>{c.status}</span></td>
                <td>{c.channel}</td>
                <td>{c.last_message_preview}</td>
                <td>{c.variant}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
