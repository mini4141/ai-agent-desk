import { createContext, useContext, useMemo, useState, type ReactNode } from "react";

const dict = {
  ja: {
    inbox: "受信トレイ", knowledge: "ナレッジ", tools: "ツール", latency: "レイテンシ", metrics: "指標", settings: "設定", signOut: "サインアウト",
    email: "メールアドレス", password: "パスワード", signIn: "サインイン", open: "対応中", resolved: "解決済み", noConversations: "会話はありません",
    channel: "チャネル", status: "状態", preview: "最新メッセージ", variant: "実験", send: "送信", sendDraft: "AI下書きを送信", takeOver: "引き継ぐ",
    handBack: "AIに戻す", resolve: "解決にする", draft: "AI下書き（編集可）", tags: "タグ", forbidden: "この画面は管理者のみ利用できます。",
    addSource: "ソースを追加", reindex: "再インデックス", chunks: "チャンク", test: "テスト実行", rollup: "再集計", deflection: "解決率（自己解決）",
    handoff: "引き継ぎ率", csat: "CSAT", aht: "平均対応時間", conversion: "ツール実行率", experiment: "実験: greeting_v2", budget: "予算",
    cacheHit: "キャッシュヒット率", live: "リアルタイム", toolCall: "ツール呼び出し", intake: "インタビュー回答",
  },
  en: {
    inbox: "Inbox", knowledge: "Knowledge", tools: "Tools", latency: "Latency", metrics: "Metrics", settings: "Settings", signOut: "Sign out",
    email: "Email", password: "Password", signIn: "Sign in", open: "Open", resolved: "Resolved", noConversations: "No conversations",
    channel: "Channel", status: "Status", preview: "Latest message", variant: "Variant", send: "Send", sendDraft: "Send AI draft", takeOver: "Take over",
    handBack: "Hand back to AI", resolve: "Resolve", draft: "AI draft (editable)", tags: "Tags", forbidden: "This page is for admins only.",
    addSource: "Add source", reindex: "Reindex", chunks: "Chunks", test: "Run test", rollup: "Recompute", deflection: "Deflection",
    handoff: "Handoff rate", csat: "CSAT", aht: "Avg handle time", conversion: "Tool conversion", experiment: "Experiment: greeting_v2", budget: "Budget",
    cacheHit: "Cache hit rate", live: "Live", toolCall: "Tool call", intake: "Interview answers",
  },
} as const;

export type Key = keyof (typeof dict)["ja"];
type Lang = "ja" | "en";
const Ctx = createContext<{ lang: Lang; setLang: (l: Lang) => void; t: (k: Key) => string }>({ lang: "ja", setLang: () => {}, t: (k) => dict.ja[k] });

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>((localStorage.getItem("agent-desk-lang") as Lang) ?? "ja");
  const value = useMemo(() => ({
    lang,
    setLang: (l: Lang) => { localStorage.setItem("agent-desk-lang", l); setLangState(l); },
    t: (k: Key) => dict[lang][k],
  }), [lang]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export const useI18n = () => useContext(Ctx);
