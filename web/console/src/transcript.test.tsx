import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act, render, screen } from "@testing-library/react";
import { expect, it, vi } from "vitest";
import type { Message } from "./api";
import { LiveTranscript } from "./components/LiveTranscript";
import { I18nProvider } from "./i18n";

const handlers: { current?: (e: any) => void } = {}; // eslint-disable-line @typescript-eslint/no-explicit-any
vi.mock("./cable", () => ({
  subscribe: (_c: string, _p: unknown, onEvent: (e: unknown) => void) => {
    handlers.current = onEvent as (e: any) => void; // eslint-disable-line @typescript-eslint/no-explicit-any
    return () => {};
  },
}));

const msg = (id: number, role: Message["role"], content: string): Message => ({ id, role, content, citations: [], metadata: {}, timings: {}, created_at: "" });

it("shows streamed AI tokens live, then the final message and the AI draft", async () => {
  const onDraft = vi.fn();
  const qc = new QueryClient();
  qc.setQueryData(["conversation", 7], { id: 7, messages: [msg(1, "customer", "配送はいつ？")] });
  render(
    <QueryClientProvider client={qc}>
      <I18nProvider><LiveTranscript conversationId={7} messages={[msg(1, "customer", "配送はいつ？")]} onDraft={onDraft} /></I18nProvider>
    </QueryClientProvider>,
  );

  act(() => handlers.current?.({ type: "token", run_id: "r1", text: "2〜3営業日" }));
  act(() => handlers.current?.({ type: "token", run_id: "r1", text: "です。" }));
  expect(screen.getByTestId("msg-streaming")).toHaveTextContent("2〜3営業日です。");

  act(() => handlers.current?.({ type: "message", message: { ...msg(2, "ai", "2〜3営業日です。"), metadata: { run_id: "r1" } } }));
  expect(screen.queryByTestId("msg-streaming")).not.toBeInTheDocument();
  expect(qc.getQueryData<{ messages: Message[] }>(["conversation", 7])?.messages).toHaveLength(2);

  act(() => handlers.current?.({ type: "draft", draft: "確認します" }));
  expect(onDraft).toHaveBeenCalledWith("確認します");
});
