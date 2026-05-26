import { test as base, expect, type Page } from "@playwright/test";
import {
  seedUser,
  seedBook as seedBookHelper,
  performEnqueuedJobs as performJobsHelper,
  uniqueSuffix,
  type SeedBookOptions,
  type SeedBookResult,
  type PerformJobsResult,
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
  // Authenticated page with kindle_email and kindle_sender_approved: true.
  kindleReadyPage: Page;
  // Bound helper for creating Book records inline within a spec.
  seedBook: (options?: SeedBookOptions) => Promise<SeedBookResult>;
  // Bound helper for draining the ActiveJob test queue inline within a spec.
  performEnqueuedJobs: (only?: string) => Promise<PerformJobsResult>;
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
  kindleReadyPage: async ({ page }, use) => {
    await seedUser(page, { kindle_email: `kindle-${uniqueSuffix()}@kindle.com` });
    await use(page);
  },
  seedBook: async ({ page }, use) => {
    await use((options = {}) => seedBookHelper(page, options));
  },
  performEnqueuedJobs: async ({ page }, use) => {
    await use((only?: string) => performJobsHelper(page, only));
  },
});

export { expect };
