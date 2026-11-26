import { expect, test } from "@playwright/test";
import { apiGet, apiToken, ask, openWidget } from "./helpers";

// Cloud runs use a Polly-synthesised utterance that real Transcribe hears; the expectations are overridable.
const HEARD = new RegExp(process.env.VOICE_HEARD ?? "注文|A-?1023", "i");
const ANSWER = process.env.VOICE_EXPECT ?? "出荷済み";

async function holdToTalk(page: import("@playwright/test").Page, ms = Number(process.env.HOLD_MS ?? 1200)) {
  const ptt = page.getByTestId("ptt");
  const box = (await ptt.boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.waitForTimeout(ms);
  await page.mouse.up();
}

test.beforeEach(async ({ page }) => {
  // Headless Chromium has no real speech recognition: the mock STT path takes this transcript hint.
  // Local: headless Chromium has no speech recognition, so the mock STT path takes this transcript hint.
  // Cloud (SPEECH_PROVIDER=aws): the hint is ignored and Transcribe hears the fake-microphone audio file instead.
  await page.addInitScript(() => ((window as unknown as Record<string, string>).__AGENT_DESK_STT_HINT__ = "注文 A-1023 はいつ届きますか？"));
});

test("voice: hold-to-talk (fake mic) gets a spoken reply", async ({ page }) => {
  await openWidget(page);
  await page.getByTestId("tab-voice_web").click();
  await expect(page.getByTestId("widget").locator(".dot.on")).toBeVisible();
  await holdToTalk(page);
  await expect(page.getByTestId("bubble-customer").last()).toContainText(HEARD, { timeout: 30_000 });
  await expect(page.getByTestId("bubble-ai").last()).toContainText(ANSWER, { timeout: 30_000 });
  await expect(page.getByTestId("spoken")).toContainText(ANSWER, { timeout: 30_000 });
});

test("avatar: speaks the answer and the interview fields are stored on the conversation", async ({ page }) => {
  await openWidget(page);
  await page.getByTestId("tab-avatar").click();
  await expect(page.getByTestId("avatar")).toBeVisible();
  await expect(page.getByTestId("widget").locator(".dot.on")).toBeVisible();
  await holdToTalk(page);
  await expect(page.getByTestId("spoken")).toContainText(ANSWER, { timeout: 30_000 });

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

  // find the interview conversation among the newest avatar conversations
  const token = await apiToken("owner@mirai.example");
  const { conversations } = await apiGet<{ conversations: { id: number; channel: string }[] }>("/api/v1/conversations", token);
  const details = await Promise.all(
    conversations.filter((c) => c.channel === "avatar").slice(0, 8)
      .map((c) => apiGet<{ intake: { completed?: boolean; answers?: Record<string, string> } }>(`/api/v1/conversations/${c.id}`, token)),
  );
  const done = details.find((d) => d.intake?.completed && d.intake.answers?.product === "ワイヤレスイヤホン");
  expect(done, "interview fields are stored on the conversation").toBeTruthy();
});
