import { Page } from '@playwright/test';

// A short, per-call random tag for namespacing seeded records. The e2e DB is
// shared across the suite (see `bin/e2e-server`) and tests run in parallel —
// use this to keep titles, emails, or queries from colliding between tests.
export function uniqueSuffix(): string {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

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
  name?: string;
  admin?: boolean;
}

export interface SeedUserResult {
  id: number;
  email: string;
  password: string;
  admin: boolean;
}

// POST /e2e/seed_user — creates a user and signs them in. The response sets a
// session cookie on `page`'s browser context, so subsequent navigations are
// authenticated without driving the sign-up form.
export async function seedUser(page: Page, options: SeedUserOptions = {}): Promise<SeedUserResult> {
  const email = options.email ?? `test-${uniqueSuffix()}@familioteca.local`;
  const password = options.password ?? 'password123';
  const response = await page.request.post('/e2e/seed_user', {
    data: { email, password, name: options.name, admin: options.admin ?? false },
  });
  if (!response.ok()) {
    throw new Error(`seedUser failed: ${response.status()} ${await response.text()}`);
  }
  return await response.json();
}

export interface SeedBookOptions {
  title?: string;
  author?: string;
  description?: string;
  object_key?: string;
}

export interface SeedBookResult {
  id: number;
  title: string;
}

// POST /e2e/seed_book — creates a Book record directly (no S3 upload). Pass
// `object_key` if a spec needs deterministic keys; otherwise a random one is
// generated server-side.
export async function seedBook(page: Page, options: SeedBookOptions = {}): Promise<SeedBookResult> {
  const response = await page.request.post('/e2e/seed_book', { data: options });
  if (!response.ok()) {
    throw new Error(`seedBook failed: ${response.status()} ${await response.text()}`);
  }
  return await response.json();
}

export interface PerformJobsResult {
  drained: number;
}

// POST /e2e/perform_jobs — drains the ActiveJob test queue synchronously,
// running each enqueued job to completion. Use to assert post-job state
// (e.g., a KindleDelivery row transitioning from pending → sent).
export async function performEnqueuedJobs(page: Page): Promise<PerformJobsResult> {
  const response = await page.request.post('/e2e/perform_jobs');
  if (!response.ok()) {
    throw new Error(`performEnqueuedJobs failed: ${response.status()} ${await response.text()}`);
  }
  return await response.json();
}
