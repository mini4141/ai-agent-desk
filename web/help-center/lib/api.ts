// Server-side data access: the help center renders knowledge articles from the Rails public API.
export const API_URL = process.env.API_URL ?? "http://localhost:3000";
export const PUBLIC_API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3000";
export const OTLP_URL = process.env.NEXT_PUBLIC_OTLP_URL;

export interface CompanyInfo { name: string; slug: string; locale: "ja" | "en"; public_key: string }
export interface ArticleSummary { id: number; title: string; excerpt: string }
export interface Article { id: number; title: string; sections: [string, string?][] }

async function get<T>(path: string): Promise<T | null> {
  const res = await fetch(`${API_URL}${path}`, { next: { revalidate: 30 } });
  return res.ok ? ((await res.json()) as T) : null;
}

export const listArticles = (slug: string, q?: string) =>
  get<{ company: CompanyInfo; articles: ArticleSummary[] }>(`/public/v1/${slug}/articles${q ? `?q=${encodeURIComponent(q)}` : ""}`);

export const getArticle = (slug: string, id: string) => get<{ company: CompanyInfo; article: Article }>(`/public/v1/${slug}/articles/${id}`);
