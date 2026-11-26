export const API_URL: string = import.meta.env.VITE_API_URL ?? "http://localhost:3000";

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export const tokenStore = {
  get: () => localStorage.getItem("agent-desk-token"),
  set: (t: string) => localStorage.setItem("agent-desk-token", t),
  clear: () => localStorage.removeItem("agent-desk-token"),
};

export async function api<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const token = tokenStore.get();
  const res = await fetch(`${API_URL}${path}`, {
    method: init.method ?? "GET",
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  if (!res.ok) throw new ApiError(res.status, (await res.json().catch(() => ({}))).error ?? res.statusText);
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T);
}

export interface Conversation {
  id: number;
  channel: string;
  status: "ai" | "waiting_human" | "human" | "resolved";
  variant: string;
  language: string | null;
  csat: number | null;
  messages_count: number;
  last_message_at: string | null;
  last_message_preview: string | null;
  draft_reply: string | null;
  tags: string[];
  intake: { answers?: Record<string, string>; completed?: boolean };
  escalation_reason: string | null;
}

export interface Message {
  id: number | string;
  role: "customer" | "ai" | "operator" | "tool";
  content: string;
  citations: { n: number; title: string; url: string }[];
  metadata: Record<string, unknown>;
  timings: Record<string, number | boolean>;
  created_at: string;
}

export type ConversationDetail = Conversation & { messages: Message[] };
