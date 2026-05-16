import { test as base, expect, type Page } from "@playwright/test";
import { seedUser } from "./helpers";

// Custom Playwright fixtures. Tests opt into a fixture by naming it in the
// destructured args — Playwright wires the setup/teardown automatically.
//
// Add new fixtures here (not inline in specs) so multiple specs can share
// the same setup. Page-object fixtures should be added alongside the
// PageObject class in `test/e2e/pages/`.

type Fixtures = {
  // An authenticated page: a fresh user seeded and signed in via cookie.
  authenticatedPage: Page;
};

export const test = base.extend<Fixtures>({
  authenticatedPage: async ({ page }, use) => {
    await seedUser(page);
    await use(page);
  },
});

export { expect };
