# Development

How to run, develop, and test Familioteca locally.

## Stack

- **Ruby** 3.3+
- **Rails** 8 — built-in `authentication` generator (User + Session + password-reset)
- **SQLite** for app data, Solid Queue, and Solid Cache
- **Hotwire** (Turbo + Stimulus)
- **Tailwind CSS** via `tailwindcss-rails` (standalone binary; no Node in the asset pipeline)
- **Vitest** + **happy-dom** for JavaScript unit tests
- **Playwright** (Node) for e2e tests
- **CircleCI** for CI; **GitHub Actions** for deploy

## Architecture

Single Rails app, deployed to one Fly.io Machine with a persistent volume mounted at `/rails/storage` for the SQLite files.

Domain code lives in namespaces. Non-ActiveRecord service objects live under `app/services/<namespace>/`.

Background jobs run on Solid Queue (SQLite-backed). Because SQLite has a single writer, worker count is tuned against write contention, not CPU count.

## Commands

- `bin/setup` — install dependencies, prepare the database. `--reset` drops and recreates the DB first.
- `bin/dev` — start the dev server on `http://localhost:3005` with the Tailwind watcher; prints the demo credentials in the terminal banner.
- `bin/rails test` — Rails unit, controller, and integration tests.
- `npm run test:js` — Vitest JS unit tests (Stimulus controllers against happy-dom).
- `npm run test:e2e` — Playwright e2e tests; boots a Rails test server on a free port automatically.
- `bin/rubocop -a` — auto-fix Ruby lint errors.
- `npm run lint:fix` — auto-fix JS lint errors.
- `bin/ci` — every check CI runs (lint + audits + tests). Wired as a pre-push git hook.

## Testing

Tests live at five layers, from fastest to slowest:

1. **Model tests** — model in isolation, no HTTP requests
2. **Controller tests** — one HTTP request per test, no browser
3. **Integration tests** — multiple HTTP requests in sequence, no browser
4. **JavaScript unit tests** — Stimulus controllers against happy-dom
5. **Playwright e2e tests** — real browser against a running server

Ruby tests (1–3) run via `bin/rails test`. JS unit tests run via `npm run test:js`. Playwright runs via `npm run test:e2e`.

There is no separate view test layer and no Rails system tests / Capybara. Controller tests with `assert_select` cover view assertions; Playwright covers everything JS-driven or end-to-end critical.

### Model tests

A single model in isolation — validations, methods, calculations, scopes. No HTTP requests, no views. The fastest tests.

### Controller tests

One HTTP request directly to Rails in-process. No browser, no JavaScript, no CSS rendering. Raw HTML back, checked with `assert_select`. Run in milliseconds.

### Integration tests

Multiple HTTP requests in sequence — a multi-step workflow, still without a browser. Both controller and integration tests inherit from `ActionDispatch::IntegrationTest`; the distinction is conceptual: controller tests focus on one endpoint, integration tests verify a flow across several requests.

If a flow doesn't involve JavaScript, an integration test is faster than Playwright. If it does, use Playwright.

### JavaScript unit tests

A Stimulus controller in isolation, with [Vitest](https://vitest.dev/) and [happy-dom](https://github.com/capricorn86/happy-dom) — no server, no browser. Mount a handwritten DOM fragment, start the controller, fire events, assert on the DOM and mocked network calls.

Tests live at `test/js/controllers/<name>.test.js`, with shared helpers in `test/js/helpers.js`.

### Playwright e2e tests

A real browser against a running Rails test server. JavaScript executes, Turbo navigates, Stimulus controllers fire, CSS renders.

### Comparison

| | Model | Controller | Integration | JS unit | Playwright e2e |
|---|---|---|---|---|---|
| Exercises | One model | One request (route, controller, view) | Multiple requests | One Stimulus controller + DOM | Full browser + JS |
| Broken HTML structure | No | Yes | Yes | No | Yes |
| Wrong data displayed | No | Yes | Yes | No | Yes |
| Auth/authorization bugs | No | Yes | Yes | No | Yes |
| Multi-step flows | No | No | Yes | No | Yes |
| JavaScript (Turbo, Stimulus) | No | No | No | Stimulus only | Yes |
| Form interactions (dropdowns, modals) | No | No | No | If Stimulus-driven | Yes |
| Visual layout issues | No | No | No | No | Partially |
| Speed | ~1ms | ~10ms | ~20ms | ~5ms | ~2–5s |
| Flakiness | Never | Almost never | Almost never | Almost never | Sometimes |

### When to use which

**Rule of thumb:** if you can test it by calling the endpoint and reading the HTML, write a controller test. If you need to click, type, wait, or see JavaScript side effects, write Playwright. If you only need to test data logic, write a model test.

**Use a model test when:** validations, business logic on models, scopes, computed methods.

**Use a controller test when:** request goes in, HTML comes out — no JS involved. Page renders the right shape, auth redirects, 404s, flash messages.

**Use an integration test when:** multi-step flow that doesn't depend on JavaScript. Most multi-step UI flows involve JS (Turbo) and Playwright covers them better — use integration tests sparingly.

**Use a JS unit test when:**

- A Stimulus controller has branching logic you want to cover without paying the e2e cost
- You need to test against many input variants (keyboard keys, error paths)
- Behavior depends on DOM events (keydown, click, custom events) and mocked `fetch` / `localStorage`

Skip if the controller is just glue (pure view toggles with no logic) — e2e covers those incidentally.

**Use a Playwright e2e test when:**

A. The flow is a main flow of the app — broken would make the app unusable.

B. Behavior requires a real browser — server round-trips, Turbo (Drive / Frame / Stream) integration, CSS-driven visibility, or cross-page/reload persistence that unit tests can't see.

### E2e conventions

E2e tests describe **flows**, not pages.

#### File structure

```
test/e2e/
  fixtures.ts        — custom Playwright fixtures
  helpers.ts         — seed API helpers
  pages/             — page objects (one per view)
  tests/             — spec files (one per feature)
```

#### Page objects

One page object per view or partial view. Don't mix concerns from different pages into one class.

Page objects own navigation via `goto()` methods. Tests should not call `page.goto("/path")` for views that have a page object. **All locators are defined in page objects** — no `page.locator` or `page.getBy*` in tests. **All assertions live in tests** — no `expect()` in page objects.

#### Fixtures

Extend `fixtures.ts` instead of calling seed helpers directly in a spec. Prefer adding assertions to an existing test over creating a new one.

#### When to write an e2e test

Only for behavior that controller tests can't cover, or for a complete end-to-end main flow:

- JavaScript-driven interactions (Stimulus, Turbo frame updates, keyboard shortcuts)
- Multi-step user flows across pages
- Browser-specific behavior (localStorage, Escape key handling)
- Live Turbo Stream broadcasts

If `assert_select` in a controller test already covers the assertion, skip the e2e test.

#### Data setup

Use seed API helpers (defined in `test/e2e/helpers.ts`) instead of UI flows when you just need data to exist. Use page-object methods only when testing that specific UI flow.

#### Locators

Prefer `id` attributes on interactive elements over text matching. Add `id` to the view HTML when needed and reference it via a named `Locator` on the page object.

### Running tests

```sh
# All Ruby tests
bin/rails test

# Specific layers
bin/rails test test/models
bin/rails test test/controllers
bin/rails test test/integration

# JS unit
npm run test:js
npm run test:js:watch   # re-run on file changes

# Playwright e2e (boots a Rails test server on a free port)
npm run test:e2e

# Full check (run before considering any task done)
bin/ci
```
