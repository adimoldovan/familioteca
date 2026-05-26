import { type Page, type Locator } from "@playwright/test";

export class AccountPage {
  readonly page: Page;
  readonly breadcrumbCurrent: Locator;
  readonly nameInput: Locator;
  readonly emailDisplay: Locator;
  readonly kindleEmailInput: Locator;
  readonly kindleSenderApprovedCheckbox: Locator;
  readonly submitButton: Locator;
  readonly errorSummary: Locator;
  readonly flash: Locator;

  constructor(page: Page) {
    this.page = page;
    this.breadcrumbCurrent = page.locator(".crumbs__current");
    this.nameInput = page.locator("#account-name");
    this.emailDisplay = page.locator("#account-email");
    this.kindleEmailInput = page.locator("#account-kindle-email");
    this.kindleSenderApprovedCheckbox = page.locator("#account-kindle-sender-approved");
    this.submitButton = page.locator("#account-submit");
    this.errorSummary = page.locator(".error-summary");
    this.flash = page.locator(".flash--notice");
  }

  async goto() {
    await this.page.goto("/account");
  }

  async fillName(name: string) {
    await this.nameInput.fill(name);
  }

  async fillKindleEmail(email: string) {
    await this.kindleEmailInput.fill(email);
  }

  async submit() {
    await this.submitButton.click();
  }
}
