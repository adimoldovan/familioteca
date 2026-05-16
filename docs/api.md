# API

Conventions for Familioteca's HTTP JSON API. The API is a parallel surface to the web UI; both share a service layer in `app/services/<namespace>/`.

This document is the source of truth for shape and conventions. Once endpoints exist, the auto-generated reference will live at `docs/api/openapi.yaml`.

## URL shape

- All API routes live under `/api/v1/...`.
- Resource names are plural and snake_case (`/entries`, `/subscriptions`, `/read_later`). Singleton resources (no list view) stay singular: `/session`, `/me`, `/library`.
- Sub-resources for state toggles use POST/DELETE pairs, mirroring the existing `entries/{read,star,read_later}_states` controllers: `POST /api/v1/entries/:id/star`, `DELETE /api/v1/entries/:id/star`.

## Authentication

Bearer token on the existing `Session` model.

- `POST /api/v1/session` with `{ "email": ..., "password": ... }` returns `{ "token": "...", "user": { ... } }`. The `sessions` table has an `api_token` column (32 random bytes, urlsafe base64, unique index, generated on creation).
- `POST /api/v1/users` with `{ "email_address": ..., "password": ... }` registers a new user and returns the same `{ token, user }` shape as sign-in. v1 does not require email confirmation, matching the web `/sign_up` flow.
- Subsequent requests send `Authorization: Bearer <token>`. The token resolves to a `Session`, which resolves to a `User` and sets `Current.user` exactly like the web flow.
- `DELETE /api/v1/session` revokes the current token (destroys the `Session` row).
- `GET /api/v1/me` returns the user payload behind the current token. Mobile clients call it on cold-start to validate a cached token (a 401 means the token was revoked) and refresh user fields like `timezone` and `admin` without re-prompting for a password.
- `DELETE /api/v1/me` deletes the authenticated user's account and returns `204 No Content`. The cascade removes every session (revoking all outstanding tokens), subscriptions, `user_entries`, and tags. Required by Apple App Store guideline §5.1.1(v) and Google Play's equivalent in-app account-deletion rule. Hard delete — no anonymization or retention window — since the data is per-user feed state with no recovery use case.
- 2FA: if a session needs admin re-auth, that's an admin-UI concern, not an API concern. The first-party mobile app does not get admin endpoints.
- Token rotation: not in v1. A revoked token is gone; the client signs in again.

We do not use Doorkeeper or OAuth. The only client is a first-party mobile app; refresh tokens and scopes would be unused infrastructure.

### Token lifecycle

Tokens have no TTL and no heartbeat or refresh. A token lives as long as its `Session` row, and is revoked by deleting that row. Two paths revoke:

- `DELETE /api/v1/session` — destroys the current session, invalidating that one token.
- Password reset (`PasswordsController#update`, web or API) — calls `@user.sessions.destroy_all`, invalidating **every** token (and web session) the user has.

Rationale: short-lived tokens with refresh rotation buy little for a first-party mobile client (no third-party token theft surface, no shared device pattern), and they cost real complexity — background sync failures, mid-request 401s, refresh-race bugs. The only realistic compromise vector the user can self-serve against is "I think someone has my password," and resetting the password already wipes every outstanding token.

If a logged-in "change password" form is added later, it must call `sessions.destroy_all` and then start a fresh session for the current device, matching the reset flow.

### Password reset

- `POST /api/v1/passwords` with `{ "email_address": ... }` always returns `202 Accepted`. The endpoint never reveals whether the address belongs to a registered account; a matching account triggers the same reset email the web flow sends.
- `PATCH /api/v1/passwords/:token` with `{ "password": ..., "password_confirmation": ... }` validates the signed token, updates the password, and destroys **every** session for the user (returns `204 No Content`). The mobile client must sign in again with the new password — by design, since reset is the documented "wipe all tokens" path. An invalid or expired token returns `404 invalid_token`; a validation failure returns `422 validation_failed`.
- The reset URL in the email is the same web URL the browser flow uses. Mobile apps should intercept it via iOS Universal Links / Android App Links — no separate API-only deep-link space.

## Response format

Plain JSON. No envelope.

```json
GET /api/v1/entries/123
{ "id": 123, "title": "...", "url": "...", "published_at": "2026-05-09T...", ... }
```

Lists return an object with `data` and `next_cursor`:

```json
GET /api/v1/entries?filter=unread
{ "data": [ { "id": 123, ... }, ... ], "next_cursor": "eyJpZCI6MTAwfQ" }
```

`next_cursor` is `null` when no more pages exist. Pass it back as `?cursor=...` to fetch the next page.

## Error format

```json
{ "error": { "code": "not_found", "message": "Entry not found" } }
```

- HTTP status is the source of truth (404, 422, etc.); `code` is a stable, snake_case symbol the client can branch on.
- Validation errors include a `details` array: `{ "code": "validation_failed", "message": "...", "details": [{ "field": "email", "code": "invalid" }] }`.

## Pagination

Cursor-based on `entries.id` (entries are naturally id-ordered, and offset pagination breaks under concurrent inserts). Default page size 50, max 200. Cursors are opaque to clients — base64-encoded JSON server-side, format may change.

## Rate limiting

Rack::Attack guards two abuse vectors:

- **Sign-in (per IP)**: `POST /api/v1/session` is capped at 10 attempts per 3 minutes per IP, shared with the web sign-in form.
- **Registration (per IP)**: `POST /api/v1/users` is capped at 10 attempts per 3 minutes per IP, shared with the web `/sign_up` form.
- **Password reset (per IP)**: `POST /api/v1/passwords` is capped at 10 attempts per 3 minutes per IP, shared with the web `/passwords` form. Prevents enumeration and outbound-mailer abuse.
- **Per-token quota**: all `/api/v1/*` requests except `POST /api/v1/session` count toward a 300 requests / minute bucket keyed on the bearer token.

When a limit is hit, the response is `429 Too Many Requests` with the standard error envelope:

```json
{ "error": { "code": "rate_limited", "message": "Too many requests. Retry after 42s." } }
```

The `Retry-After` header carries the same value in seconds. Clients should back off until the window resets rather than retrying immediately.

## Versioning

URL prefix only (`/api/v1`). A breaking change cuts `/api/v2`; `/api/v1` keeps working until every active client has migrated. Additive changes (new fields, new endpoints) do not bump the version.

## CORS

Not configured. The only client is a first-party native mobile app, which issues plain HTTP requests outside any browser origin model — CORS preflight and `Access-Control-*` headers are a browser concern and don't apply.

If a browser-based client is added later (a third-party web app, a separate SPA on another origin), revisit this: pull in `rack-cors`, restrict it to `/api/v1/*`, and allowlist the specific origins. Until then, no `rack-cors` gem and no middleware — adding it pre-emptively would be infrastructure that protects nothing and has to be kept in sync with a phantom origin list.

## Implementation notes

- **Controllers**: namespaced under `Api::V1::`, inheriting from a thin `Api::V1::BaseController` that handles token auth and JSON error rendering. Skip `protect_from_forgery` (token auth replaces CSRF for the API surface).
- **Serializers**: plain Ruby PORO under `app/serializers/api/v1/`. No gem until we feel the pain.
- **Services**: API and HTML controllers both call into `app/services/<namespace>/` services. Inline logic gets extracted opportunistically as each API endpoint is built — no big-bang refactor PR.
- **Tests**: controller tests under `test/controllers/api/v1/`, hitting the JSON layer directly. Service-level tests stay where the service lives.

