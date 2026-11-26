import { useMutation, useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { ApiError, api } from "../api";
import { useI18n } from "../i18n";

interface ToolRow { id: number; name: string; description: string; endpoint: string; params_schema: { properties?: Record<string, unknown> } }

const SAMPLE: Record<string, object> = {
  check_order_status: { order_id: "A-1023" },
  book_callback: { phone: "090-1234-5678", time: "15:00" },
};

export function Tools() {
  const { t } = useI18n();
  const { data, error } = useQuery({ queryKey: ["tools"], queryFn: () => api<{ tools: ToolRow[] }>("/api/v1/tools") });
  const [result, setResult] = useState<Record<number, unknown>>({});
  const test = useMutation({
    mutationFn: (tool: ToolRow) => api<{ output: unknown }>(`/api/v1/tools/${tool.id}/test`, { method: "POST", body: { input: SAMPLE[tool.name] ?? {} } }),
    onSuccess: (res, tool) => setResult((r) => ({ ...r, [tool.id]: res.output })),
  });
  if (error instanceof ApiError && error.status === 403) return <p className="error" data-testid="forbidden">{t("forbidden")}</p>;

  return (
    <section>
      <h2>{t("tools")}</h2>
      {data?.tools.map((tool) => (
        <article key={tool.id} className="card" data-testid="tool-card">
          <h3>{tool.name}</h3>
          <p>{tool.description}</p>
          <p className="mono">{tool.endpoint}</p>
          <button onClick={() => test.mutate(tool)}>{t("test")}</button>
          {result[tool.id] !== undefined && <pre data-testid="tool-output">{JSON.stringify(result[tool.id], null, 2)}</pre>}
        </article>
      ))}
    </section>
  );
}
