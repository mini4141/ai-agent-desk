export type Locale = "ja" | "en";

const dict = {
  ja: {
    title: "サポート", placeholder: "メッセージを入力", send: "送信", chat: "チャット", voice: "音声", avatar: "アバター",
    hold: "押しながら話す", listening: "聞き取り中…", speaking: "話しています…", human: "担当者が対応中です",
    waiting: "担当者をお呼びしています…", helpful: "解決しました", notHelpful: "解決しませんでした", thanks: "ご評価ありがとうございました",
    interview: "返品インタビュー", sources: "参照", tool: "ツール実行", intakeName: "お名前", intakeProduct: "商品", intakeReason: "理由",
  },
  en: {
    title: "Support", placeholder: "Type a message", send: "Send", chat: "Chat", voice: "Voice", avatar: "Avatar",
    hold: "Hold to talk", listening: "Listening…", speaking: "Speaking…", human: "A teammate is handling this chat",
    waiting: "Connecting you with a teammate…", helpful: "Resolved", notHelpful: "Not resolved", thanks: "Thanks for your feedback",
    interview: "Return interview", sources: "Sources", tool: "Tool call", intakeName: "Name", intakeProduct: "Product", intakeReason: "Reason",
  },
} as const;

export type Dict = (typeof dict)["ja"];

export const t = (locale: Locale): Dict => dict[locale] as Dict;

export const browserLocale = (): Locale => (navigator.language.startsWith("ja") ? "ja" : "en");
