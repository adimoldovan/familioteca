import { test, expect } from "../fixtures";
import { BookShowPage } from "../pages/BookShowPage";

test.describe("Send to Kindle", () => {
  test("a member without a kindle email sees the help notice instead of the button", async ({ authenticatedPage, seedBook }) => {
    const book = await seedBook({ title: "Doi Ani de Vacanta" });
    const show = new BookShowPage(authenticatedPage);
    await show.gotoById(book.id);

    await expect(show.kindleSendButton).toHaveCount(0);
    await expect(show.kindleNotice).toContainText("Email Kindle");
  });

  test("clicking Trimite pe Kindle swaps the button for a 'Se trimite...' status", async ({ kindleReadyPage, seedBook }) => {
    const book = await seedBook({ title: "Doi Ani de Vacanta" });
    const show = new BookShowPage(kindleReadyPage);
    await show.gotoById(book.id);

    await expect(show.kindleSendButton).toBeVisible();
    await show.kindleSendButton.click();
    await expect(show.kindleStatus).toContainText("Se trimite");
  });

  test("after the job runs, the page reflects the sent status", async ({ kindleReadyPage, seedBook, performEnqueuedJobs }) => {
    const book = await seedBook({ title: "Doi Ani de Vacanta" });
    const show = new BookShowPage(kindleReadyPage);
    await show.gotoById(book.id);

    await show.kindleSendButton.click();
    await expect(show.kindleStatus).toContainText("Se trimite");

    const result = await performEnqueuedJobs("SendToKindleJob");
    expect(result.drained).toBeGreaterThanOrEqual(1);
    await kindleReadyPage.reload();

    await expect(show.kindleStatus).toContainText("Trimisă");
  });
});
