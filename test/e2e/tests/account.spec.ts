import { test, expect } from "../fixtures";
import { AccountPage } from "../pages/AccountPage";

test.describe("Account", () => {
  test("member navigates to account page via nav link", async ({ authenticatedPage }) => {
    await authenticatedPage.goto("/");
    await authenticatedPage.locator("#nav-account").click();

    const account = new AccountPage(authenticatedPage);
    await expect(account.heading).toHaveText("Contul meu");
    await expect(account.nameInput).toBeVisible();
    await expect(account.emailDisplay).toBeVisible();
    await expect(account.kindleEmailInput).toBeVisible();
  });

  test("member updates name and kindle email", async ({ authenticatedPage }) => {
    const account = new AccountPage(authenticatedPage);
    await account.goto();

    await account.fillName("Maria Ionescu");
    await account.fillKindleEmail("maria@kindle.com");
    await account.submit();

    await expect(account.flash).toContainText("Cont actualizat");
    await expect(account.nameInput).toHaveValue("Maria Ionescu");
    await expect(account.kindleEmailInput).toHaveValue("maria@kindle.com");
  });

  test("validation error is shown when name is blank", async ({ authenticatedPage }) => {
    const account = new AccountPage(authenticatedPage);
    await account.goto();

    await account.fillName("");
    // Bypass browser-level required validation to test server-side errors
    await account.nameInput.evaluate((el) => el.removeAttribute("required"));
    await account.submit();

    await expect(account.errorSummary).toBeVisible();
  });
});
