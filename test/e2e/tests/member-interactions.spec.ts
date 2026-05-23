import { test, expect } from "../fixtures";
import { uniqueSuffix } from "../helpers";
import { BookShowPage } from "../pages/BookShowPage";

test.describe("Member interactions", () => {
  test("setting Mi-a plăcut highlights the active button and persists on reload", async ({ authenticatedPage, seedBook }) => {
    const book = await seedBook({ title: `Doi Ani de Vacanță ${uniqueSuffix()}`, author: "Jules Verne" });

    const show = new BookShowPage(authenticatedPage);
    await show.gotoById(book.id);

    await expect(show.activeRating).toHaveCount(0);
    await show.ratingMiAPlacut.click();
    await expect(show.activeRating).toHaveCount(1);
    await expect(show.activeRating).toContainText("Mi-a plăcut");

    await authenticatedPage.reload();
    await expect(show.activeRating).toHaveCount(1);
    await expect(show.activeRating).toContainText("Mi-a plăcut");
  });

  test("clicking the active rating again clears it", async ({ authenticatedPage, seedBook }) => {
    const book = await seedBook({ title: `Doi Ani de Vacanță ${uniqueSuffix()}` });
    const show = new BookShowPage(authenticatedPage);
    await show.gotoById(book.id);

    await show.ratingAsaSiAsa.click();
    await expect(show.activeRating).toHaveCount(1);

    await show.ratingAsaSiAsa.click();
    await expect(show.activeRating).toHaveCount(0);
  });

  test("marking a book as read flips the button and persists on reload", async ({ authenticatedPage, seedBook }) => {
    const book = await seedBook({ title: `Cluj ${uniqueSuffix()}` });
    const show = new BookShowPage(authenticatedPage);
    await show.gotoById(book.id);

    await expect(show.markReadButton).toBeVisible();
    await show.markReadButton.click();

    await expect(show.markUnreadButton).toBeVisible();

    await authenticatedPage.reload();
    await expect(show.markUnreadButton).toBeVisible();
  });
});
