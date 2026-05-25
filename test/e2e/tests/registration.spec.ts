import { test, expect } from "../fixtures";
import {
  createInviteCode,
  getPasswordResetToken,
  seedUser,
  uniqueSuffix,
} from "../helpers";

test.describe("Registration", () => {
  test("family member registers with a valid invite code", async ({ page }) => {
    const { code } = await createInviteCode(page);
    const suffix = uniqueSuffix();

    await page.goto(`/register/${code}`);
    await expect(page.locator("h1")).toHaveText("Înregistrare");

    await page.locator("#register-name").fill(`Membru ${suffix}`);
    await page.locator("#register-email").fill(`new-${suffix}@test.local`);
    await page.locator("#register-password").fill("password123");
    await page.locator("#register-password-confirmation").fill("password123");
    await page.locator("#register-submit").click();

    await expect(page).toHaveURL("/");
    await expect(page.getByPlaceholder("Caută…")).toBeVisible();
  });

  test("used invite code is rejected", async ({ page }) => {
    const { code } = await createInviteCode(page);
    const suffix = uniqueSuffix();

    await page.goto(`/register/${code}`);
    await page.locator("#register-name").fill(`First ${suffix}`);
    await page.locator("#register-email").fill(`first-${suffix}@test.local`);
    await page.locator("#register-password").fill("password123");
    await page.locator("#register-password-confirmation").fill("password123");
    await page.locator("#register-submit").click();
    await expect(page).toHaveURL("/");

    await page.context().clearCookies();
    await page.goto(`/register/${code}`);

    await expect(page).toHaveURL("/sign_in");
    await expect(page.locator(".flash.flash--alert")).toContainText("invalid sau a fost deja folosit");
  });

  test("invalid invite code is rejected", async ({ page }) => {
    await page.goto("/register/BOGUS-CODE-999");

    await expect(page).toHaveURL("/sign_in");
    await expect(page.locator(".flash.flash--alert")).toContainText("invalid sau a fost deja folosit");
  });

  test("password reset flow — set new password and sign in", async ({ page }) => {
    const suffix = uniqueSuffix();
    const email = `reset-flow-${suffix}@test.local`;
    const oldPassword = "oldpassword123";
    const newPassword = "newpassword456";

    await seedUser(page, { email, password: oldPassword, name: `Reset ${suffix}` });
    await page.context().clearCookies();

    const { token } = await getPasswordResetToken(page, email);
    await page.goto(`/password_resets/${token}/edit`);

    await expect(page.locator("h1")).toHaveText("Resetare parolă");
    await page.locator("#reset-password").fill(newPassword);
    await page.locator("#reset-password-confirmation").fill(newPassword);
    await page.locator("#reset-submit").click();

    await expect(page).toHaveURL("/sign_in");
    await expect(page.locator(".flash.flash--notice")).toContainText("Parola a fost schimbată");

    await page.locator("#sign-in-email").fill(email);
    await page.locator("#sign-in-password").fill(newPassword);
    await page.locator("#sign-in-submit").click();

    await expect(page).toHaveURL("/");
  });

  test("invalid reset token shows error", async ({ page }) => {
    await page.goto("/password_resets/invalid-token-xyz/edit");

    await expect(page).toHaveURL("/sign_in");
    await expect(page.locator(".flash.flash--alert")).toContainText("expirat sau este invalid");
  });
});
