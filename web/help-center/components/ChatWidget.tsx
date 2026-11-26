import Script from "next/script";
import { OTLP_URL, PUBLIC_API_URL } from "@/lib/api";

// Embeds the shared chat / voice / avatar widget (Shadow DOM bundle served by the Rails app).
export function ChatWidget({ publicKey }: { publicKey: string }) {
  return (
    <Script
      src={`${PUBLIC_API_URL}/widget.js`}
      strategy="afterInteractive"
      data-key={publicKey}
      data-api={PUBLIC_API_URL}
      data-channels="web_chat,voice_web,avatar"
      data-otlp={OTLP_URL}
    />
  );
}
