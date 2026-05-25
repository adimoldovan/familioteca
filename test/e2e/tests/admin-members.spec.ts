import { test, expect } from "../fixtures";
import { AdminMembersPage } from "../pages/AdminMembersPage";
import { seedMemberInSeparateContext, uniqueSuffix } from "../helpers";

test.describe("Admin members", () => {
  test("admin generates invite code and sees it listed", async ({ adminPage }) => {
    await adminPage.goto("/admin/invite_codes");

    const heading = adminPage.locator("#invite-codes-heading");
    await expect(heading).toHaveText("Coduri de invitație");

    await adminPage.getByRole("button", { name: "Generează cod nou" }).click();

    await expect(adminPage.locator(".flash.flash--notice")).toBeVisible();
    const table = adminPage.locator("table[aria-labelledby='invite-codes-heading']");
    const firstRow = table.locator("tbody tr").first();
    await expect(firstRow.locator("code")).not.toBeEmpty();
    await expect(firstRow.getByText("Activ")).toBeVisible();
  });

  test("admin generates reset link and sees the URL", async ({ adminPage }) => {
    const suffix = uniqueSuffix();
    const memberName = `Resetabil ${suffix}`;
    await seedMemberInSeparateContext(adminPage, {
      name: memberName,
      email: `reset-${suffix}@test.local`,
    });

    const membersPage = new AdminMembersPage(adminPage);
    await membersPage.goto();

    // Turbo Drive does not render POST 200 responses in this context; bypass
    // Turbo so the browser performs a normal form submission.
    const resetBtn = membersPage.resetLinkButtonFor(memberName);
    await resetBtn.evaluate((btn) => btn.closest("form")!.setAttribute("data-turbo", "false"));
    await resetBtn.click();

    const resetUrl = adminPage.locator("#reset-url");
    await expect(resetUrl).toBeVisible();
    const urlText = await resetUrl.textContent();
    expect(urlText).toMatch(/\/password_resets\/.{20,}\/edit/);
  });

  test("admin deletes a member", async ({ adminPage }) => {
    const suffix = uniqueSuffix();
    const memberName = `Ștergibil ${suffix}`;
    await seedMemberInSeparateContext(adminPage, {
      name: memberName,
      email: `delete-${suffix}@test.local`,
    });

    const membersPage = new AdminMembersPage(adminPage);
    await membersPage.goto();

    await expect(membersPage.table.getByText(memberName)).toBeVisible();

    adminPage.on("dialog", (dialog) => dialog.accept());
    await membersPage.deleteButtonFor(memberName).click();

    await expect(adminPage.locator(".flash.flash--notice")).toContainText("Membrul a fost șters");
    await expect(membersPage.table.getByText(memberName)).toHaveCount(0);
  });
});
