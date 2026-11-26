import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "../api";
import { useI18n } from "../i18n";

interface Summary { conversations: number; deflection_rate: number | null; handoff_rate: number | null; csat: number | null; csat_responses: number; avg_handle_seconds: number | null; tool_conversion: number | null }
interface Report {
  totals: Summary;
  by_variant: Record<string, Summary>;
  by_channel: Record<string, Summary>;
  by_day: (Summary & { day: string })[];
  experiment: { status?: string; deflection_delta_pp?: number; p_value?: number; sample_size?: { control: number; treatment: number }; note?: string };
}

const pct = (v: number | null) => (v == null ? "–" : `${(v * 100).toFixed(1)}%`);

export function Metrics() {
  const { t } = useI18n();
  const qc = useQueryClient();
  const { data } = useQuery({ queryKey: ["metrics"], queryFn: () => api<Report>("/api/v1/metrics") });
  const rollup = useMutation({ mutationFn: () => api("/api/v1/metrics/rollup", { method: "POST" }), onSuccess: () => void qc.invalidateQueries({ queryKey: ["metrics"] }) });
  if (!data) return <p>…</p>;
  const { totals, experiment } = data;
  const control = data.by_variant.control;
  const v2 = data.by_variant.greeting_v2;
  const days = data.by_day;
  const max = Math.max(1, ...days.map((d) => d.conversations));

  return (
    <section>
      <div className="row"><h2>{t("metrics")}</h2><button onClick={() => rollup.mutate()}>{t("rollup")}</button></div>
      <div className="tiles">
        <Tile label="Conversations" value={String(totals.conversations)} testId="kpi-conversations" />
        <Tile label={t("deflection")} value={pct(totals.deflection_rate)} testId="kpi-deflection" />
        <Tile label={t("handoff")} value={pct(totals.handoff_rate)} />
        <Tile label={t("csat")} value={totals.csat?.toFixed(2) ?? "–"} />
        <Tile label={t("aht")} value={totals.avg_handle_seconds ? `${totals.avg_handle_seconds}s` : "–"} />
        <Tile label={t("conversion")} value={pct(totals.tool_conversion)} />
      </div>

      <h3>{t("experiment")}</h3>
      <table data-testid="variant-table">
        <thead><tr><th>Variant</th><th>n</th><th>{t("deflection")}</th><th>{t("handoff")}</th><th>{t("csat")}</th><th>{t("conversion")}</th></tr></thead>
        <tbody>
          {([["control", control], ["greeting_v2", v2]] as const).map(([name, s]) => s && (
            <tr key={name}><td>{name}</td><td>{s.conversations}</td><td>{pct(s.deflection_rate)}</td><td>{pct(s.handoff_rate)}</td><td>{s.csat?.toFixed(2) ?? "–"}</td><td>{pct(s.tool_conversion)}</td></tr>
          ))}
        </tbody>
      </table>
      {experiment.deflection_delta_pp !== undefined && (
        <p className="card" data-testid="experiment-delta">
          Δ deflection <b>{experiment.deflection_delta_pp > 0 ? "+" : ""}{experiment.deflection_delta_pp} pp</b> (p = {experiment.p_value}) · n = {experiment.sample_size?.control} / {experiment.sample_size?.treatment}
          <br /><small>{experiment.note}</small>
        </p>
      )}

      <h3>Conversations / day</h3>
      <svg viewBox={`0 0 ${Math.max(days.length, 1) * 24} 80`} className="spark" role="img" aria-label="conversations per day">
        {days.map((d, i) => <rect key={d.day} x={i * 24 + 3} y={80 - (d.conversations / max) * 76} width="18" height={(d.conversations / max) * 76} fill="#2557d6" />)}
      </svg>
    </section>
  );
}

function Tile({ label, value, testId }: { label: string; value: string; testId?: string }) {
  return <div className="tile" data-testid={testId}><small>{label}</small><strong>{value}</strong></div>;
}
