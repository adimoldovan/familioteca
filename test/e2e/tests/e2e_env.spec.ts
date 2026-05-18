// Smoke test for the e2e env wiring. Verifies that the seed endpoints boot
// and return JSON so Phase 2 specs have a working baseline. Catalog UI
// assertions live in their own page-object-backed specs.
import { test, expect } from "../fixtures";

test("seed_book endpoint creates a Book record", async ({ seedBook }) => {
  const book = await seedBook({ title: "Smoke Test Title", author: "Smoke Author" });

  expect(book.id).toBeGreaterThan(0);
  expect(book.title).toBe("Smoke Test Title");
});

test("adminPage fixture seeds an admin member and sets session cookie", async ({ adminPage }) => {
  // /admin/books is admin-gated; a 200 confirms both the session cookie and
  // the admin? flag were applied by seed_user.
  const response = await adminPage.request.get("/admin/books");

  expect(response.status()).toBe(200);
});
