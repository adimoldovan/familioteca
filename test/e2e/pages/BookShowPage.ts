import { type Page, type Locator } from "@playwright/test";

export class BookShowPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly downloadLink: Locator;
  readonly breadcrumbCatalog: Locator;

  // Rating
  readonly ratingNuMiAPlacut: Locator;
  readonly ratingAsaSiAsa: Locator;
  readonly ratingMiAPlacut: Locator;
  readonly activeRating: Locator;

  // Read toggle
  readonly markReadButton: Locator;
  readonly markUnreadButton: Locator;
  readonly readStatus: Locator;

  // Kindle
  readonly kindleSendButton: Locator;
  readonly kindleStatus: Locator;
  readonly kindleNotice: Locator;

  constructor(page: Page) {
    this.page = page;
    this.heading = page.locator("h1.book-detail__title");
    this.downloadLink = page.locator("#book-download-link");
    this.breadcrumbCatalog = page.locator("nav.crumbs a");

    this.ratingNuMiAPlacut = page.locator("#rating-nu_mi_a_placut");
    this.ratingAsaSiAsa = page.locator("#rating-asa_si_asa");
    this.ratingMiAPlacut = page.locator("#rating-mi_a_placut");
    this.activeRating = page.locator("#book-rating .journal__rate-btn.is-active");

    this.markReadButton = page.locator("#read-mark-button");
    this.markUnreadButton = page.locator("#read-unmark-button");
    this.readStatus = page.locator("#read-status");

    this.kindleSendButton = page.locator("#kindle-send-button");
    this.kindleStatus = page.locator("#kindle-status");
    this.kindleNotice = page.locator("#book-kindle .kindle__notice");
  }

  async gotoById(id: number) {
    await this.page.goto(`/books/${id}`);
  }
}
