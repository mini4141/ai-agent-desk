import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState, type FormEvent } from "react";
import { api } from "../api";
import { useI18n } from "../i18n";

interface Source { id: number; kind: string; title: string | null; url: string | null; status: string; chunks_count: number; error: string | null }

export function Knowledge() {
  const { t } = useI18n();
  const qc = useQueryClient();
  const [kind, setKind] = useState("url");
  const [url, setUrl] = useState("");
  const [content, setContent] = useState("");

  // Poll while any source is still being crawled/embedded by Sidekiq.
  const { data } = useQuery({
    queryKey: ["knowledge"],
    queryFn: () => api<{ knowledge_sources: Source[] }>("/api/v1/knowledge_sources"),
    refetchInterval: (q) => (q.state.data?.knowledge_sources.some((s) => s.status === "pending" || s.status === "processing") ? 1500 : false),
  });
  const refresh = () => void qc.invalidateQueries({ queryKey: ["knowledge"] });
  const add = useMutation({ mutationFn: () => api("/api/v1/knowledge_sources", { method: "POST", body: kind === "url" ? { kind, url } : { kind, content, title: "Upload" } }), onSuccess: refresh });
  const reindex = useMutation({ mutationFn: (id: number) => api(`/api/v1/knowledge_sources/${id}/reindex`, { method: "POST" }), onSuccess: refresh });
  const submit = (e: FormEvent) => { e.preventDefault(); add.mutate(); };
  const sources = data?.knowledge_sources ?? [];
  const total = sources.reduce((n, s) => n + s.chunks_count, 0);

  return (
    <section>
      <h2>{t("knowledge")} <small data-testid="chunk-total">{total} {t("chunks")}</small></h2>
      <form className="inline" onSubmit={submit}>
        <select value={kind} onChange={(e) => setKind(e.target.value)}><option value="url">URL</option><option value="markdown">Markdown</option></select>
        {kind === "url" ? <input placeholder="http://company-backend:4567/sites/mirai/delivery.html" value={url} onChange={(e) => setUrl(e.target.value)} /> : <textarea value={content} onChange={(e) => setContent(e.target.value)} />}
        <button type="submit">{t("addSource")}</button>
      </form>
      <table>
        <thead><tr><th>#</th><th>Title</th><th>URL</th><th>{t("status")}</th><th>{t("chunks")}</th><th /></tr></thead>
        <tbody>
          {sources.map((s) => (
            <tr key={s.id} data-testid="source-row">
              <td>{s.id}</td><td>{s.title}</td><td className="mono">{s.url}</td>
              <td><span className={`badge ${s.status}`}>{s.status}</span>{s.error && <small> {s.error}</small>}</td>
              <td>{s.chunks_count}</td>
              <td><button onClick={() => reindex.mutate(s.id)}>{t("reindex")}</button></td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
