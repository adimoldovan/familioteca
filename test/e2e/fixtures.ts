import { test as base, expect, type Page } from "@playwright/test";
import {
  seedUser,
  seedBook as seedBookHelper,
  type SeedBookOptions,
  type SeedBookResult,
} from "./helpers";

// Custom Playwright fixtures. Tests opt into a fixture by naming it in the
// destructured args — Playwright wires the setup/teardown automatically.
//
// Add new fixtures here (not inline in specs) so multiple specs can share
// the same setup. Page-object fixtures should be added alongside the
// PageObject class in `test/e2e/pages/`.

type Fixtures = {
  // An authenticated page: a fresh user seeded and signed in via cookie.
  authenticatedPage: Page;
  // Same as `authenticatedPage`, but the seeded member is an admin.
  adminPage: Page;
  // Bound helper for creating Book records inline within a spec.
  seedBook: (options?: SeedBookOptions) => Promise<SeedBookResult>;
};

export const test = base.extend<Fixtures>({
  authenticatedPage: async ({ page }, use) => {
    await seedUser(page);
    await use(page);
  },
  adminPage: async ({ page }, use) => {
    await seedUser(page, { admin: true });
    await use(page);
  },
  seedBook: async ({ page }, use) => {
    await use((options = {}) => seedBookHelper(page, options));
  },
});

export { expect };
