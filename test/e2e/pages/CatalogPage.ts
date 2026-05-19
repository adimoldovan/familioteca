import { type Page, type Locator } from "@playwright/test";

export class CatalogPage {
  readonly page: Page;
  readonly searchInput: Locator;
  readonly bookCards: Locator;
  readonly emptyState: Locator;

  constructor(page: Page) {
    this.page = page;
    this.searchInput = page.locator("input#q");
    this.bookCards = page.locator(".book-card");
    this.emptyState = page.locator(".empty-state");
  }

  async goto() {
    await this.page.goto("/");
  }

  async search(query: string) {
    await this.searchInput.fill(query);
    await this.searchInput.press("Enter");
  }

  bookCardByTitle(title: string): Locator {
    return this.bookCards.filter({
      has: this.page.locator(".book-card__title", { hasText: exactText(title) }),
    });
  }
}

function exactText(value: string): RegExp {
  const escaped = value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`^${escaped}$`);
}
