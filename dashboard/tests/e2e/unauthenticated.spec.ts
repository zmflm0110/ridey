import { expect, test } from "@playwright/test";

const paths = [
  "/",
  "/overview",
  "/priority",
  "/districts",
  "/route",
  "/field",
  "/records",
  "/lists",
  "/staff",
  "/forbidden",
];

test("unsigned visitors only see the login page", async ({ page }) => {
  const urls: string[] = [];
  page.on("request", (request) => urls.push(request.url()));

  for (const path of paths) {
    await page.goto(path);
    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByRole("heading", { name: "로그인" })).toBeVisible();
    await expect(page.getByRole("navigation", { name: "운영" })).toHaveCount(0);
    await expect(page.locator("body")).not.toContainText("SPB-");
  }

  expect(urls.filter((url) => /supabase\.co|\/rest\/v1|\/auth\/v1/.test(url))).toEqual([]);
});
