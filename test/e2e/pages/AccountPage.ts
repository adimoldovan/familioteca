import { type Page, type Locator } from "@playwright/test";

export class AccountPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly nameInput: Locator;
  readonly emailDisplay: Locator;
  readonly kindleEmailInput: Locator;
  readonly submitButton: Locator;
  readonly errorSummary: Locator;
  readonly flash: Locator;

  constructor(page: Page) {
    this.page = page;
    this.heading = page.locator("#account-heading");
    this.nameInput = page.locator("#account-name");
    this.emailDisplay = page.locator("#account-email");
    this.kindleEmailInput = page.locator("#account-kindle-email");
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
