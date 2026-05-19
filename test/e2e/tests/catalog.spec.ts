import { test, expect } from "../fixtures";
import { uniqueSuffix } from "../helpers";
import { CatalogPage } from "../pages/CatalogPage";
import { BookShowPage } from "../pages/BookShowPage";

test.describe("Catalog", () => {
  test("a signed-in member browses to a book and sees its metadata", async ({ authenticatedPage, seedBook }) => {
    const suffix = uniqueSuffix();
    const title = `Doi Ani de Vacanță ${suffix}`;
    await seedBook({ title, author: "Jules Verne" });

    const catalog = new CatalogPage(authenticatedPage);
    await catalog.goto();
    await catalog.search(title);

    const card = catalog.bookCardByTitle(title);
    await expect(card).toBeVisible();
    await card.click();

    const show = new BookShowPage(authenticatedPage);
    await expect(show.heading).toHaveText(title);
    await expect(show.downloadLink).toBeVisible();
  });

  test("search matches Romanian diacritics insensitively", async ({ authenticatedPage, seedBook }) => {
    const suffix = uniqueSuffix();
    const matching = `Bizanț ${suffix}`;
    const nonMatching = `Cluj ${suffix}`;
    await seedBook({ title: matching, author: "Lucian Boia" });
    await seedBook({ title: nonMatching, author: "Other" });

    const catalog = new CatalogPage(authenticatedPage);
    await catalog.goto();

    await catalog.search(`bizant ${suffix}`);
    await expect(catalog.bookCards).toHaveCount(1);
    await expect(catalog.bookCardByTitle(matching)).toBeVisible();
  });

  test("empty search shows the no-results message", async ({ authenticatedPage, seedBook }) => {
    const suffix = uniqueSuffix();
    await seedBook({ title: `Cluj ${suffix}`, author: "Other" });
    const catalog = new CatalogPage(authenticatedPage);
    await catalog.goto();

    const query = `xxnomatchxx-${suffix}`;
    await catalog.search(query);
    await expect(catalog.emptyState).toContainText(query);
  });
});
