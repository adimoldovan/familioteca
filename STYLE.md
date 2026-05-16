# Style

Opinionated conventions for code, tests, and writing in this repo.

## Writing

- Direct and concise. No corporate adjectives ("comprehensive", "robust", "extensive", "seamless").
- Commit messages: multiple `-m` flags, not `$(cat <<EOF … EOF)` heredocs.

## Ruby / Rails

- Domain code lives in namespaces; non-ActiveRecord service objects go in `app/services/<namespace>/`.
- Env-specific settings belong in `config/environments/*.rb`, not env-var exports in `bin/` scripts.
- Solid Queue worker count is tuned against SQLite write contention, not CPU count.
- Don't add gems or npm packages until the feature using them is actively being built.

## HTML / CSS

- Add `id` attributes to unique interactive elements; tests use them as locators.
- Component classes are BEM (`.foo`, `.foo__part`, `.foo--mod`) in `app/assets/tailwind/application.css` — don't rebuild them with utility soup.
- Prefer design tokens (CSS custom properties) over raw hex/font/size values. See [docs/design.md](docs/design.md).
- Never use inline `style="…"`. Define a class in `application.css` — no carve-out for one-offs.

## Tests

- Pick the lowest layer that proves the behavior; Playwright e2e is for complete user flows or browser-only behavior.
- Page objects own locators; tests own assertions. No `expect()` in `test/e2e/pages/*`; no `page.locator()` or `page.getBy*()` in specs.
- E2e tests use fixtures (`test/e2e/fixtures.ts`), not inline seed helper calls.
- Prefer adding assertions to an existing test over creating a new one.
