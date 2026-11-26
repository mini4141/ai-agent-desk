import { expect, type Page } from "@playwright/test";
import { urls } from "../playwright.config";

export const PASSWORD = process.env.SEED_PASSWORD ?? "agentdesk-demo";

export async function openWidget(page: Page, company = "mirai") {
  await page.goto(`${urls.help}/${company}/help`);
  await page.getByTestId("launcher").click();
  await expect(page.getByTestId("widget")).toBeVisible();
  // the conversation is ready once Action Cable is subscribed (history delivered)
  await expect(page.getByTestId("widget").locator(".dot.on")).toBeVisible({ timeout: 20_000 });
}

export async function ask(page: Page, text: string) {
  await page.getByTestId("input").fill(text);
  await page.getByTestId("send").click();
}

export async function loginConsole(page: Page, email: string) {
  await page.goto(urls.console);
  await page.getByTestId("email").fill(email);
  await page.getByTestId("password").fill(PASSWORD);
  await page.getByTestId("signin").click();
  await expect(page.getByTestId("whoami")).toBeVisible();
}

export async function apiToken(email: string): Promise<string> {
  const res = await fetch(`${urls.api}/api/v1/session`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email, password: PASSWORD }) });
  return (await res.json()).token as string;
}

export async function apiGet<T>(path: string, token: string): Promise<T> {
  const res = await fetch(`${urls.api}${path}`, { headers: { Authorization: `Bearer ${token}` } });
  return (await res.json()) as T;
}
