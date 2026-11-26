import { useQuery } from "@tanstack/react-query";
import { API_URL, ApiError, api } from "../api";
import { useI18n } from "../i18n";

interface Company { name: string; slug: string; locale: string; public_key: string; allowed_origins: string[] }

export function Settings() {
  const { t } = useI18n();
  const { data, error } = useQuery({ queryKey: ["company"], queryFn: () => api<Company>("/api/v1/companies/me") });
  if (error instanceof ApiError && error.status === 403) return <p className="error">{t("forbidden")}</p>;
  if (!data) return <p>…</p>;
  const snippet = `<script src="${API_URL}/widget.js" data-key="${data.public_key}" data-channels="web_chat,voice_web,avatar"></script>`;
  return (
    <section>
      <h2>{t("settings")}</h2>
      <dl className="card">
        <dt>Company</dt><dd>{data.name} ({data.locale})</dd>
        <dt>Public key</dt><dd className="mono">{data.public_key}</dd>
        <dt>Allowed origins</dt><dd>{data.allowed_origins.join(", ") || "*"}</dd>
        <dt>Embed</dt><dd><pre>{snippet}</pre></dd>
      </dl>
    </section>
  );
}
