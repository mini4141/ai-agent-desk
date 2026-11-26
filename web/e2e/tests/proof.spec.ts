// Captures the proof screenshots (CLAUDE.md §8). Run via scripts/capture-proof.sh; it is a normal Playwright spec,
// so the same flow reproduces every image. PROOF_SET=cloud switches to the phase-2 file names.
import { expect, test, type Page } from "@playwright/test";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { urls } from "../playwright.config";
import { ask, loginConsole, openWidget } from "./helpers";

const cloud = process.env.PROOF_SET === "cloud";
const dir = process.env.PROOF_DIR ?? "../../proof/phase1-local/screenshots";
mkdirSync(dir, { recursive: true });
const shot = (page: Page, name: string) => page.screenshot({ path: join(dir, `${name}.png`) });

test.skip(!process.env.CAPTURE_PROOF, "proof capture only runs from scripts/capture-proof.sh");

const names = cloud
  ? { chat: "01-cloud-chat-bedrock", voice: "02-cloud-voice-transcribe-polly", avatar: "03-cloud-avatar-visemes", operator: "04-cloud-operator", latency: "05-cloud-latency" }
  : {
      chat: "01-chat-ja-streaming-citation", tool: "02-tool-call-order-status", voice: "03-voice-widget", avatar: "04-avatar-interview", phone: "05-phone-sim",
      inbox: "06-console-inbox", operator: "07-operator-takeover", latency: "08-latency-dashboard", metrics: "09-metrics-experiment",
      help: "10-help-center-ssr", jaeger: "11-jaeger-trace", knowledge: "12-knowledge-sources",
    };

test.describe.configure({ mode: "serial" });

test("chat, tool call and citation", async ({ page }) => {
  await openWidget(page);
  if (!cloud) {
    await ask(page, "返品はできますか？");
    await expect(page.getByTestId("citations").last()).toContainText("[1]");
    await page.waitForTimeout(500);
    await shot(page, names.chat);
    await ask(page, "注文 A-1023 はいつ届きますか？");
    await expect(page.getByTestId("tool-chip")).toContainText("check_order_status");
    await expect(page.getByTestId("bubble-ai").last()).toContainText("出荷済み");
    await page.waitForTimeout(500);
    await shot(page, names.tool!);
  } else {
    await ask(page, "注文 A-1023 はいつ届きますか？");
    await expect(page.getByTestId("tool-chip")).toContainText("check_order_status", { timeout: 40_000 });
    await expect(page.getByTestId("bubble-ai").last()).toContainText("A-1023", { timeout: 40_000 });
    await page.waitForTimeout(800);
    await shot(page, names.chat);
  }
});

test("voice and avatar", async ({ page }) => {
  await page.addInitScript(() => ((window as unknown as Record<string, string>).__AGENT_DESK_STT_HINT__ = "注文 A-1023 はいつ届きますか？"));
  await openWidget(page);
  const hold = async () => {
    const box = (await page.getByTestId("ptt").boundingBox())!;
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.mouse.down();
    await page.waitForTimeout(1500);
    await page.mouse.up();
  };
  await page.getByTestId("tab-voice_web").click();
  await expect(page.getByTestId("widget").locator(".dot.on")).toBeVisible();
  await hold();
  await expect(page.getByTestId("spoken")).not.toHaveText("", { timeout: 40_000 });
  await shot(page, names.voice);

  await page.getByTestId("tab-avatar").click();
  await expect(page.getByTestId("widget").locator(".dot.on")).toBeVisible();
  await hold();
  await expect(page.getByTestId("spoken")).not.toHaveText("", { timeout: 40_000 });
  await shot(page, names.avatar);
  if (!cloud) {
    await page.getByTestId("interview-toggle").click();
    await expect(page.getByTestId("widget").locator(".dot.on")).toBeVisible();
    await ask(page, "山田花子");
    await expect(page.getByTestId("bubble-ai").last()).toContainText("商品名");
    await ask(page, "ワイヤレスイヤホン");
    await expect(page.getByTestId("bubble-ai").last()).toContainText("理由");
    await ask(page, "音が出ません");
    await expect(page.getByTestId("bubble-ai").last()).toContainText("承りました");
    await page.waitForTimeout(1200);
    await shot(page, names.avatar);
  }
});

test("operator inbox, takeover, latency and metrics", async ({ browser }) => {
  const customer = await (await browser.newContext()).newPage();
  const operator = await (await browser.newContext({ viewport: { width: 1280, height: 860 } })).newPage();
  await loginConsole(operator, "sato@mirai.example");
  await openWidget(customer);
  await ask(customer, "返品はできますか？");
  await expect(customer.getByTestId("bubble-ai").last()).toContainText("返品");
  const marker = `#${Date.now()}`;
  await ask(customer, `人と話したいです。注文の件でご相談があります。${marker}`);
  await expect(customer.getByTestId("waiting-human")).toBeVisible();
  const row = operator.locator('[data-testid="inbox-row"][data-status="waiting_human"]', { hasText: marker });
  await expect(row).toBeVisible({ timeout: 10_000 });
  if (!cloud) await shot(operator, names.inbox!);
  await row.getByRole("link").click();
  await expect(operator.getByTestId("draft")).not.toHaveValue("", { timeout: 10_000 });
  await operator.getByTestId("draft").fill("担当の佐藤です。ご相談内容を詳しくお聞かせください。");
  await operator.getByTestId("send").click();
  await expect(customer.getByTestId("bubble-operator")).toContainText("担当の佐藤です");
  await operator.waitForTimeout(800);
  await shot(operator, names.operator);

  const owner = await (await browser.newContext({ viewport: { width: 1280, height: 1000 } })).newPage();
  await loginConsole(owner, "owner@mirai.example");
  await owner.getByRole("link", { name: /レイテンシ|Latency/ }).click();
  await expect(owner.getByTestId("latency-card").first()).toBeVisible();
  await owner.waitForTimeout(600);
  await shot(owner, names.latency);
  if (!cloud) {
    await owner.getByRole("link", { name: /指標|Metrics/ }).click();
    await expect(owner.getByTestId("experiment-delta")).toBeVisible();
    await shot(owner, names.metrics!);
    await owner.getByRole("link", { name: /ナレッジ|Knowledge/ }).click();
    await expect(owner.getByTestId("source-row").first()).toBeVisible();
    await shot(owner, names.knowledge!);
  }
});

test("phone, help center and Jaeger", async ({ page }) => {
  test.skip(cloud, "local-only screenshots");
  await page.goto(urls.phone);
  await page.getByTestId("call").click();
  await expect(page.getByTestId("state")).toHaveAttribute("data-state", "in-call", { timeout: 15_000 });
  const box = (await page.getByTestId("talk").boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.waitForTimeout(1200);
  await page.mouse.up();
  await expect(page.getByTestId("log")).toContainText("agent:", { timeout: 15_000 });
  await page.waitForTimeout(500);
  await shot(page, names.phone!);

  await page.goto(`${urls.help}/mirai/help`);
  await expect(page.getByTestId("launcher")).toBeVisible();
  await shot(page, names.help!);

  // find a trace that spans widget -> Rails and open it in Jaeger
  const jaeger = process.env.JAEGER_URL ?? "http://localhost:16686";
  const found = await (await fetch(`${jaeger}/api/traces?service=agent-desk-widget&limit=20&lookback=1h`)).json();
  const trace = (found.data as { traceID: string; spans: { processID: string }[]; processes: Record<string, { serviceName: string }> }[])
    .filter((t) => new Set(Object.values(t.processes).map((p) => p.serviceName)).size > 1)
    .sort((a, b) => b.spans.length - a.spans.length)[0];
  expect(trace, "a widget -> Rails trace exists in Jaeger").toBeTruthy();
  await page.goto(`${jaeger}/trace/${trace.traceID}`);
  await expect(page.getByText("agent-desk-rails").first()).toBeVisible({ timeout: 15_000 });
  await page.waitForTimeout(1000);
  await shot(page, names.jaeger!);
});
