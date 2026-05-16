import { Page } from '@playwright/test';

// Seed-API helpers. Each helper POSTs to a `/e2e/<name>` endpoint that the
// Rails app exposes only in `RAILS_ENV=e2e`. The endpoints create domain
// records directly (skipping UI flows) so specs can start in a known state.
//
// Pattern:
//   1. Add a route in `config/routes.rb` under a `constraints -> { Rails.env.e2e? }` block.
//   2. Add a thin controller in `app/controllers/e2e/` that calls the same service
//      objects the production controllers do.
//   3. Add a matching TypeScript helper here and a fixture in `fixtures.ts`.

export interface SeedUserOptions {
  email?: string;
  password?: string;
}

export interface SeedUserResult {
  id: number;
  email: string;
  password: string;
}

// POST /e2e/seed_user — creates a user and signs them in. The response sets a
// session cookie on `page`'s browser context, so subsequent navigations are
// authenticated without driving the sign-up form.
export async function seedUser(page: Page, options: SeedUserOptions = {}): Promise<SeedUserResult> {
  const email = options.email
    ?? `test-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}@familioteca.local`;
  const password = options.password ?? 'password123';
  const response = await page.request.post('/e2e/seed_user', {
    data: { email, password },
  });
  if (!response.ok()) {
    throw new Error(`seedUser failed: ${response.status()} ${await response.text()}`);
  }
  return await response.json();
}
