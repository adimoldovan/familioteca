import { defineConfig, devices } from '@playwright/test';

const port = Number(process.env.E2E_PORT) || 3334;

/**
 * See https://playwright.dev/docs/test-configuration.
 */
export default defineConfig({
  testDir: 'test/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  reporter: [["html", { open: "never" }]],
  expect: {
    timeout: 10_000,
  },
  use: {
    baseURL: `http://localhost:${port}`,
    actionTimeout: 10_000,
    trace: "retain-on-failure",
    screenshot: { mode: "only-on-failure", fullPage: true },
    // Block service-worker registration in tests. The app may register a SW in
    // production for PWA installability, but its fetch handler would bypass
    // Playwright's `page.route()` interceptors (Playwright does not route
    // requests originating from service workers). Blocking keeps specs
    // deterministic.
    serviceWorkers: "block",
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], colorScheme: 'light' },
    },
  ],

  /* Run your local dev server before starting the tests */
  webServer: {
    command: `bin/e2e-server ${port}`,
    url: `http://localhost:${port}/up`,
    reuseExistingServer: false,
    stdout: 'pipe',
    stderr: 'pipe',
    timeout: 30000, // 30 seconds to start
  },
});
