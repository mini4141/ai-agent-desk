import { expect, test } from "@playwright/test";
import { apiGet, apiToken, ask, openWidget } from "./helpers";

async function holdToTalk(page: import("@playwright/test").Page, ms = 1200) {
  const ptt = page.getByTestId("ptt");
  const box = (await ptt.boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.waitForTimeout(ms);
  await page.mouse.up();
}

test.beforeEach(async ({ page }) => {
  // Headless Chromium has no real speech recognition: the mock STT path takes this transcript hint.
  await page.addInitScript(() => ((window as unknown as Record<string, string>).__AGENT_DESK_STT_HINT__ = "注文 A-1023 はいつ届きますか？"));
});

test("voice: hold-to-talk (fake mic) gets a spoken reply", async ({ page }) => {
  await openWidget(page);
  await page.getByTestId("tab-voice_web").click();
  await expect(page.getByTestId("widget").locator(".dot.on")).toBeVisible();
  await holdToTalk(page);
  await expect(page.getByTestId("bubble-customer").last()).toContainText("A-1023");
  await expect(page.getByTestId("bubble-ai").last()).toContainText("出荷済み");
  await expect(page.getByTestId("spoken")).toContainText("出荷済み", { timeout: 15_000 });
});

test("avatar: speaks the answer and the interview fields are stored on the conversation", async ({ page }) => {
  await openWidget(page);
  await page.getByTestId("tab-avatar").click();
  await expect(page.getByTestId("avatar")).toBeVisible();
  await expect(page.getByTestId("widget").locator(".dot.on")).toBeVisible();
  await holdToTalk(page);
  await expect(page.getByTestId("spoken")).toContainText("出荷済み", { timeout: 15_000 });

  // interview mode: scripted 3-question intake
  await page.getByTestId("interview-toggle").click();
  await expect(page.getByTestId("bubble-ai").first()).toContainText("お名前");
  await expect(page.getByTestId("widget").locator(".dot.on")).toBeVisible();
  const stamp = Date.now();
  await ask(page, `テスト太郎${stamp}`);
  await expect(page.getByTestId("bubble-ai").last()).toContainText("商品名");
  await ask(page, "ワイヤレスイヤホン");
  await expect(page.getByTestId("bubble-ai").last()).toContainText("理由");
  await ask(page, "音が出ません");
  await expect(page.getByTestId("bubble-ai").last()).toContainText("承りました");

  const token = await apiToken("owner@mirai.example");
  const { conversations } = await apiGet<{ conversations: { id: number; channel: string }[] }>("/api/v1/conversations", token);
  const avatar = conversations.find((c) => c.channel === "avatar");
  const detail = await apiGet<{ intake: { completed: boolean; answers: Record<string, string> } }>(`/api/v1/conversations/${avatar!.id}`, token);
  expect(detail.intake.completed).toBe(true);
  expect(detail.intake.answers.product).toBe("ワイヤレスイヤホン");
});
