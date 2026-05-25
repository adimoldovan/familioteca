import { type Page, type Locator } from "@playwright/test";

export class AdminMembersPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly table: Locator;

  constructor(page: Page) {
    this.page = page;
    this.heading = page.locator("#members-heading");
    this.table = page.locator("table[aria-labelledby='members-heading']");
  }

  async goto() {
    await this.page.goto("/admin/members");
  }

  resetLinkButtonFor(memberName: string): Locator {
    return this.rowFor(memberName).getByRole("button", { name: /resetare/i });
  }

  deleteButtonFor(memberName: string): Locator {
    return this.rowFor(memberName).getByRole("button", { name: /șterge/i });
  }

  private rowFor(memberName: string): Locator {
    return this.table.locator("tr").filter({
      has: this.page.locator("td:first-child", { hasText: memberName }),
    });
  }
}
