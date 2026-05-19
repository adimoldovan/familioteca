import { type Page, type Locator } from "@playwright/test";

export class AdminBooksPage {
  readonly page: Page;
  readonly scanButton: Locator;
  readonly scanStatus: Locator;

  constructor(page: Page) {
    this.page = page;
    this.scanButton = page.locator("#scan-now-button");
    this.scanStatus = page.locator("#scan-status");
  }

  async goto() {
    await this.page.goto("/admin/books");
  }

  async clickScan() {
    await this.scanButton.click();
  }
}
