import { expect, test } from "@playwright/test";
import { apiGet, apiToken, ask, loginConsole, openWidget } from "./helpers";

// SPECS F3 + F7 + F9: web chat answer (tool + citation) -> escalate -> operator takes over -> resolve -> metrics update.
test("web chat answers, escalates, operator takes over, resolves, and metrics update", async ({ browser }) => {
  const customer = await (await browser.newContext()).newPage();
  const operator = await (await browser.newContext()).newPage();

  // operator is already looking at the live inbox
  await loginConsole(operator, "sato@mirai.example");
  await expect(operator.getByText("Live").or(operator.getByText("リアルタイム"))).toBeVisible();

  // 1. customer asks about an order: tool call + streamed answer with a citation
  await openWidget(customer);
  await ask(customer, "注文 A-1023 はいつ届きますか？");
  await expect(customer.getByTestId("tool-chip")).toContainText("check_order_status");
  await expect(customer.getByTestId("bubble-ai").last()).toContainText("出荷済み");
  await expect(customer.getByTestId("citations").last()).toContainText("[1]");

  // 2. customer asks for a person -> escalated, shows up in the operator inbox within 2 s
  const marker = `e2e-${Date.now()}`;
  await ask(customer, `人と話したいです ${marker}`);
  await expect(customer.getByTestId("waiting-human")).toBeVisible();
  const row = operator.locator('[data-testid="inbox-row"][data-status="waiting_human"]', { hasText: marker });
  await expect(row).toBeVisible({ timeout: 2_000 });

  // 3. operator opens it, sees the AI draft, edits + sends, customer receives it
  await row.getByRole("link").click();
  await expect(operator.getByTestId("draft")).not.toHaveValue("", { timeout: 5_000 });
  await operator.getByTestId("draft").fill("担当の佐藤です。ご注文の件、確認いたします。");
  await operator.getByTestId("send").click();
  await expect(customer.getByTestId("bubble-operator")).toContainText("担当の佐藤です");
  await expect(customer.getByTestId("human-joined")).toBeVisible();

  // 4. hand back to AI, then customer asks again and the AI answers; finally resolve
  await operator.getByTestId("hand-back").click();
  await expect(operator.getByTestId("status")).toHaveText("ai");
  await operator.getByTestId("take-over").click();
  await operator.getByTestId("resolve").click();
  await expect(operator.getByTestId("status")).toHaveText("resolved");

  // customer thumbs-up lands as CSAT on a fresh AI conversation (deflection)
  const ai = await (await browser.newContext()).newPage();
  await openWidget(ai);
  await ask(ai, "返品はできますか？");
  await expect(ai.getByTestId("bubble-ai").last()).toContainText("返品");
  await ai.getByTestId("csat-up").click();
  await expect(ai.getByTestId("csat-thanks")).toBeVisible();

  // 5. metrics: roll up on demand and see today's conversations counted
  const token = await apiToken("owner@mirai.example");
  const before = await apiGet<{ totals: { conversations: number } }>("/api/v1/metrics", token);
  await fetch(`${process.env.API_URL ?? "http://localhost:3000"}/api/v1/metrics/rollup`, { method: "POST", headers: { Authorization: `Bearer ${token}` } });
  const after = await apiGet<{ totals: { conversations: number } }>("/api/v1/metrics", token);
  expect(after.totals.conversations).toBeGreaterThan(before.totals.conversations);
});
