import { expect, test } from "@playwright/test";
import { urls } from "../playwright.config";
import { apiGet, apiToken } from "./helpers";

test("phone simulator: a call completes one question and answer over mu-law frames", async ({ page }) => {
  await page.goto(urls.phone);
  await page.getByTestId("call").waitFor();
  await page.getByTestId("call").click();
  await expect(page.getByTestId("state")).toHaveAttribute("data-state", "in-call", { timeout: 15_000 });

  const talk = page.getByTestId("talk");
  const box = (await talk.boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.waitForTimeout(Number(process.env.HOLD_MS ?? 1200));
  await page.mouse.up();

  await expect(page.getByTestId("log")).toContainText(/caller: .*(注文|1023)/, { timeout: 30_000 });
  await expect(page.getByTestId("log")).toContainText("agent:", { timeout: 30_000 });
  await expect(page.getByTestId("log")).toContainText("出荷済み");

  const token = await apiToken("owner@mirai.example");
  const { conversations } = await apiGet<{ conversations: { channel: string }[] }>("/api/v1/conversations", token);
  expect(conversations.some((c) => c.channel === "phone_sim")).toBe(true);
});

test("help center is server-rendered: article text is in the HTML without JavaScript", async ({ request }) => {
  const res = await request.get(`${urls.help}/mirai/help`);
  const html = await res.text();
  expect(html).toContain("ヘルプセンター");
  expect(html).toContain("メールアドレスとパスワードで無料登録できます");
  expect(html).toContain("<title>ミライ電機 ヘルプセンター</title>");
});

test("greeting_v2 assignment is sticky per visitor", async ({ request }) => {
  const visitor = `sticky-${Date.now()}`;
  const variants = new Set<string>();
  for (let i = 0; i < 3; i++) {
    const res = await request.post(`${urls.api}/widget/v1/sessions`, { data: { public_key: "pk_demo_mirai", visitor_id: visitor } });
    variants.add((await res.json()).variant);
  }
  expect(variants.size).toBe(1);
});
