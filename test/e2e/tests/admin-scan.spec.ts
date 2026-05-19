import { test, expect } from "../fixtures";
import { AdminBooksPage } from "../pages/AdminBooksPage";

test.describe("Admin scan flow", () => {
  test("clicking Scanează acum swaps the button for a status indicator", async ({ adminPage }) => {
    const page = new AdminBooksPage(adminPage);
    await page.goto();

    await expect(page.scanButton).toBeVisible();
    await expect(page.scanStatus).toHaveCount(0);

    await page.clickScan();

    await expect(page.scanStatus).toBeVisible();
    await expect(page.scanStatus).toContainText("Se scanează");
    await expect(page.scanButton).toHaveCount(0);
  });
});
