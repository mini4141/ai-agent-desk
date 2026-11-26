import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, expect, it, vi } from "vitest";
import { I18nProvider } from "./i18n";
import { Inbox } from "./pages/Inbox";

const handlers: { current?: (e: unknown) => void } = {};
vi.mock("./cable", () => ({
  subscribe: (_channel: string, _params: unknown, onEvent: (e: unknown) => void) => {
    handlers.current = onEvent;
    return () => {};
  },
}));

const conv = (id: number, status: string, preview: string) => ({ id, status, channel: "web_chat", variant: "control", last_message_preview: preview });
let rows = [conv(1, "waiting_human", "人と話したい"), conv(2, "ai", "配送について")];

beforeEach(() => {
  rows = [conv(1, "waiting_human", "人と話したい"), conv(2, "ai", "配送について")];
  vi.stubGlobal("fetch", vi.fn(async () => new Response(JSON.stringify({ conversations: rows }), { status: 200 })));
});

const renderInbox = () =>
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <I18nProvider><MemoryRouter><Inbox /></MemoryRouter></I18nProvider>
    </QueryClientProvider>,
  );

it("lists open conversations from the API and refreshes when Action Cable pushes an update", async () => {
  renderInbox();
  expect(await screen.findAllByTestId("inbox-row")).toHaveLength(2);
  expect(screen.getByText("人と話したい")).toBeInTheDocument();

  rows = [...rows, conv(3, "waiting_human", "返金したい")];
  handlers.current?.({ type: "conversation_updated", id: 3 });

  await waitFor(() => expect(screen.getAllByTestId("inbox-row")).toHaveLength(3));
  expect(screen.getByText("返金したい")).toBeInTheDocument();
});
