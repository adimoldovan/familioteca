import { type Page, type Locator } from "@playwright/test";

export class CatalogPage {
  readonly page: Page;
  readonly searchInput: Locator;
  readonly bookCards: Locator;
  readonly emptyState: Locator;

  constructor(page: Page) {
    this.page = page;
    this.searchInput = page.locator("#search-input");
    this.bookCards = page.locator(".book-card");
    this.emptyState = page.locator(".empty-state");
  }

  async goto() {
    await this.page.goto("/");
  }

  async search(query: string) {
    // Stimulus controllers eager-load as async ES modules (importmap), so under
    // parallel load the live-search controller may not be connected yet when we
    // type. If it isn't, the "input" event is dropped and no search ever fires —
    // wait for the controller to connect before typing.
    await this.searchInput.waitFor();
    await this.page.waitForFunction(() => {
      const field = document.querySelector("[data-controller~='live-search']");
      const stimulus = (window as unknown as {
        Stimulus?: { getControllerForElementAndIdentifier(el: Element, id: string): unknown };
      }).Stimulus;
      return Boolean(field && stimulus?.getControllerForElementAndIdentifier(field, "live-search"));
    });

    // fill dispatches the "input" event the controller listens for, which starts
    // the debounce. (The controller has no keyboard binding, so no Enter needed.)
    await this.searchInput.fill(query);

    // live_search_controller debounces input by 500ms, then Turbo.visit-s to a
    // URL carrying the trimmed query (or drops "q" when the query is blank). Wait
    // for that to commit so assertions (and back-navigation) don't race the
    // pre-visit DOM. waitForFunction polls window.location directly, so it
    // doesn't depend on a document load event — Turbo Drive's same-document
    // navigation never fires one.
    const committed = query.trim();
    await this.page.waitForFunction((expected) => {
      const q = new URLSearchParams(window.location.search).get("q");
      return expected.length > 0 ? q === expected : q === null;
    }, committed);
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
