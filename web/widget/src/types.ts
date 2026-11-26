export type Channel = "web_chat" | "voice_web" | "avatar";

export interface Citation {
  n: number;
  title: string;
  url: string;
  snippet: string;
}

export interface ChatMessage {
  id: string | number;
  role: "customer" | "ai" | "operator" | "tool";
  content: string;
  citations?: Citation[];
  metadata?: Record<string, unknown>;
  runId?: string;
  streaming?: boolean;
}

export interface Session {
  conversation_id: number;
  token: string;
  visitor_id: string;
  variant: "control" | "greeting_v2";
  company: { name: string; locale: "ja" | "en"; slug: string };
  greeting: string | null;
  suggestions: string[];
  opening: string | null;
}

export interface Viseme {
  time: number;
  value: string;
}

export interface WidgetOptions {
  api: string;
  publicKey: string;
  channels: Channel[];
  otlp?: string;
  open?: boolean;
}
