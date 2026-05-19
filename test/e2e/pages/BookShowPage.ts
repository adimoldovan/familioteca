import { type Page, type Locator } from "@playwright/test";

export class BookShowPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly downloadLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.heading = page.locator("h1.t-headline");
    this.downloadLink = page.locator("#book-download-link");
  }
}
