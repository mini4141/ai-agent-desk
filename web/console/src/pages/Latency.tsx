import { useQuery } from "@tanstack/react-query";
import { api } from "../api";
import { useI18n } from "../i18n";

interface Stage { p50: number | null; p95: number | null }
interface ChannelRow { channel: string; turns: number; cache_hit_rate: number; budget_ms: number; stages: Record<string, Stage> }
interface Report { stages: string[]; channels: ChannelRow[] }

export function Latency() {
  const { t } = useI18n();
  const { data } = useQuery({ queryKey: ["latency"], queryFn: () => api<Report>("/api/v1/metrics/latency"), refetchInterval: 10_000 });
  if (!data) return <p>…</p>;
  return (
    <section>
      <h2>{t("latency")}</h2>
      {data.channels.map((c) => {
        const e2e = c.stages.end_to_end_ms;
        const ok = (e2e?.p95 ?? 0) <= c.budget_ms;
        const scale = Math.max(c.budget_ms * 1.2, ...Object.values(c.stages).map((s) => s.p95 ?? 0));
        return (
          <article key={c.channel} className="card" data-testid="latency-card">
            <h3>{c.channel} <span className={`badge ${ok ? "resolved" : "waiting_human"}`}>{ok ? "within budget" : "over budget"}</span></h3>
            <p>{t("budget")}: {c.budget_ms} ms · {t("cacheHit")}: {(c.cache_hit_rate * 100).toFixed(0)}% · n={c.turns}</p>
            <div className="bars">
              {data.stages.map((s) => (
                <div key={s} className="bar-row">
                  <span className="label">{s}</span>
                  <div className="track">
                    <div className="bar p95" style={{ width: `${((c.stages[s].p95 ?? 0) / scale) * 100}%` }} />
                    <div className="bar p50" style={{ width: `${((c.stages[s].p50 ?? 0) / scale) * 100}%` }} />
                    <div className="budget-line" style={{ left: `${(c.budget_ms / scale) * 100}%` }} />
                  </div>
                  <span className="val">p50 {c.stages[s].p50 ?? "–"} / p95 {c.stages[s].p95 ?? "–"} ms</span>
                </div>
              ))}
            </div>
          </article>
        );
      })}
    </section>
  );
}
