# Familioteca — Design Spec

**Date:** 2026-05-16
**Status:** Approved for planning

## 1. Purpose

A Romanian-language, web-based ebook library for one family (~6 members). Members browse a shared catalog and send titles to their personal Kindle. Per-member read state (read / unread) and a 3-level rating (**mi-a plăcut** / **așa și așa** / **nu mi-a plăcut**) are tracked.

The name *Familioteca* is a blend of *familie* + *bibliotecă*.

## 2. Scope

**In scope (MVP):**
- Browse catalog of ebooks
- Per-member "mark as read" and 3-level rating (`mi_a_placut` / `asa_si_asa` / `nu_mi_a_placut`)
- Send a book to a member's Kindle by email
- One-click download fallback (presigned URL)
- Admin: edit metadata, manage member accounts, trigger an on-demand library scan
- Localization: Romanian-only UI, Romanian-aware sort and search

**Out of scope (MVP, may revisit):**
- Multi-tenant / SaaS
- Public sign-up
- Email bounce handling
- Audit log of admin actions
- Conflict resolution on concurrent admin edits
- Recommendations, comments, tags, reading progress beyond binary
- Webhook-driven instant ingest
- Visual regression and load tests

## 3. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Familioteca (Rails 8)                │
│                                                         │
│   Web (Hotwire/Turbo) ─ Controllers ─ Models ─ Mailers  │
│                              │                          │
│                         Solid Queue                     │
│                       ┌──────┴──────┐                   │
│                  IngestBookJob   SendToKindleJob        │
│                  (daily +        (on-demand)            │
│                   on-demand)                            │
└──────────┬───────────────────────────────┬──────────────┘
           │                               │
       ┌───▼────────┐                  ┌───▼──────────┐
       │ Object     │                  │  Gmail SMTP  │
       │ Storage    │                  │  (app pass)  │
       │ (S3/R2)    │                  └──────────────┘
       │ - EPUBs    │
       │ - MOBIs    │
       └────────────┘

           ┌──────────────────────────────┐         ┌───────────────┐
           │   Persistent volume (Fly.io) │         │   Tigris      │
           │   ├── familioteca.sqlite3    │ ◄─────► │   (backups)   │
           │   ├── queue.sqlite3          │ Lite-   │  litestream/  │
           │   ├── cache.sqlite3          │ stream  │  - WAL repl.  │
           │   ├── cable.sqlite3          │ (side-  │  - snapshots  │
           │   └── active_storage/        │  car)   └───────────────┘
           └──────────────────────────────┘
```

**Stack decisions:**
- **Ruby on Rails 8** monolith. Hotwire/Turbo for UI. No SPA.
- **SQLite** for app data, plus the three Rails 8 "Solid" databases (queue, cache, cable). All on a Fly.io mounted volume.
- **Active Storage** with disk service on the same volume — used only for cached cover thumbnails. Ebook files themselves stay in object storage and are never copied into Active Storage.
- **Object storage**: S3 or Cloudflare R2 (same `aws-sdk-s3` client, different endpoint). The bucket is the source of truth for ebook files. Rails reads only — it never writes.
- **Gmail SMTP** via `smtp.gmail.com:587` with a 16-character App Password on a dedicated Gmail account (e.g., `familioteca@gmail.com`). Credentials in Rails credentials file. Limits (500 recipients/day on free Gmail) are well above our needs.
- **Hosting**: Fly.io with a mounted volume. SQLite-on-PaaS narrows to Fly.io or Render-with-disk; we pick Fly.io.

## 4. Components

### 4.1 Models

- **`Member`** — `email`, `password_digest`, `kindle_email`, `name`, `admin:boolean`. Rails 8 built-in auth (`has_secure_password` + sessions). First member is admin; admins manage other members. No public sign-up.

- **`Book`** — `title`, `author`, `language`, `publisher`, `published_year`, `isbn`, `description`, `format` (`epub` / `mobi` / `pdf`), `object_key` (unique), `file_size`, `ingested_at`, `missing_since` (nullable), `parse_error` (nullable), `sort_title`, `searchable`. Has-one `cover` via Active Storage. `sort_title` and `searchable` populated via `before_save` (see §7).

- **`MemberBook`** — join on `(member_id, book_id)` unique. Columns: `read_at` (nullable timestamp), `rating` (integer-backed enum, nullable: `nu_mi_a_placut: 0`, `asa_si_asa: 1`, `mi_a_placut: 2` — ordered low→high so it sorts meaningfully). One row per member-book interaction. Created lazily on first action. Setting rating to `nil` un-rates the book.

- **`KindleDelivery`** — audit row for each send-to-Kindle attempt. Columns: `member_id`, `book_id`, `status` (`pending` / `sent` / `failed`), `error`, `sent_at`. Drives the UI badge "Sent ✓ X ago" / "Failed — retry".

### 4.2 Controllers

- `SessionsController` (`new`, `create`, `destroy`) — login / logout.
- `BooksController` (`index`, `show`) — catalog browsing. `index` supports a `q` parameter that searches `Book.searchable` (case- and diacritic-insensitive).
- `MemberBooksController` (`update`) — toggle read, set rating. Responds with Turbo Stream.
- `KindleDeliveriesController` (`create`) — enqueues `SendToKindleJob`, responds with Turbo Stream "Sending…".
- `DownloadsController` (`show`) — redirects to a 5-minute presigned URL from object storage.
- `Admin::BooksController` (`index`, `edit`, `update`) — admin index includes a "Needs metadata" filter (rows with `parse_error.present?`).
- `Admin::MembersController` (`index`, `new`, `create`, `destroy`, plus `send_reset_link`) — manage family accounts.
- `Admin::IngestionsController` (`create`) — "Scan library now" button.

Non-admin access to `/admin/*` returns 404, not 403.

### 4.3 Background jobs (Solid Queue)

- **`IngestBookJob`** — recurring (daily at 03:00 Europe/Bucharest) and on-demand. Lists object storage, diffs against `Book.pluck(:object_key)`, enqueues a `ProcessBookFileJob` per new key, marks missing keys with `missing_since: Time.current` (soft-delete; never hard-destroys rows). Concurrency-limited to 1 via `limits_concurrency to: 1, key: "ingest"` so manual + scheduled runs serialize.
- **`ProcessBookFileJob(object_key)`** — downloads one file to `/tmp`, runs `Ebook::Parser.call`, creates the `Book` row, attaches the cover. Per-file retries (3, exponential). On parse failure, the row is still created with `title = filename, parse_error = <message>` so it surfaces in admin "Needs metadata".
- **`SendToKindleJob(delivery_id)`** — streams the file from object storage, mails it via `KindleMailer.deliver_book`, updates the `KindleDelivery` row. Retries 3x. Final failed state is visible in the UI with a retry button.
- **`DiskCheckJob`** — weekly. Emails admin if the volume is >80% used.

Backups are handled outside the Rails app by Litestream — see §10.

### 4.4 Mailers

- **`KindleMailer#deliver_book(delivery)`** — attaches the ebook, recipient is `member.kindle_email`. Subject is ASCII-folded (`"Familioteca: <author-folded> - <title-folded>"`) for reliable Kindle filename handling. Body: one short Romanian line (or empty).
- **`PasswordResetMailer#reset_link(member, token)`** — Romanian body, single-use link.
- **`NewBooksDigestMailer#weekly(member, books)`** — optional, future. Stub included in spec; not required for MVP.

### 4.5 Service objects (POROs in `app/services/`)

- **`Ebook::Parser.call(path)`** — dispatches on extension to `Ebook::EpubParser` or `Ebook::MobiParser`. Returns `{ attributes: {...}, cover_io: StringIO|nil }`. Unknown formats / PDFs fall back to parsing the filename.
- **`Ebook::EpubParser`** — wraps `gepub`. Extracts title, author(s), language, publisher, published date, description, ISBN, cover image.
- **`Ebook::MobiParser`** — wraps the `mobi` gem (or falls back to filename if the gem is unreliable for a given file).
- **`BookStorage`** — wrapper over `aws-sdk-s3`, configurable for S3 or R2 (same SDK, different endpoint). Methods: `list`, `download(key)`, `presigned_url(key, expires_in:)`.
- **`DiacriticFolding.fold(string)`** — strips Romanian diacritics and lowercases. Handles both modern (`ș`, `ț`) and old (`ş`, `ţ`) forms. Used by the `Book` before_save callback.

### 4.6 Gems

- `gepub` — EPUB parsing
- `mobi` — MOBI parsing (if reliable for our files)
- `aws-sdk-s3` — object storage client
- `bcrypt` — via `has_secure_password`
- `image_processing` — cover thumbnails (via Active Storage variants)
- `rails-i18n` — Romanian translations for AR/AM/dates/etc.
- `rack-attack` — login rate limiting

## 5. Data flows

### 5.1 Ingestion

```
Trigger 1: Solid Queue recurring schedule
  every: 1.day  at: "03:00 Europe/Bucharest"
  → IngestBookJob.perform_later

Trigger 2: Admin clicks "Scan library now"
  POST /admin/ingestions
  → IngestBookJob.perform_later
  → Turbo Stream: button → "Scanning… ⟳"
  → broadcast on completion ("Added N, missing M, failed F")

IngestBookJob.perform
  remote = BookStorage.list                  # set of object keys
  known  = Book.pluck(:object_key).to_set

  (remote - known).each { |key| ProcessBookFileJob.perform_later(key) }
  Book.where(object_key: known - remote).update_all(missing_since: now)

ProcessBookFileJob(key).perform
  path = BookStorage.download(key)           # → /tmp
  result = Ebook::Parser.call(path)
  book = Book.create!(object_key: key, format: …, file_size: …, **result.attributes)
  book.cover.attach(io: result.cover_io, filename: …) if result.cover_io
ensure
  FileUtils.rm_f(path)
```

Idempotent. Re-uploads with the same `object_key` are no-ops. Missing-then-returning files clear `missing_since`.

### 5.2 Send to Kindle

```
Member clicks "Send to Kindle" on Book#show
  POST /books/:id/kindle_deliveries

KindleDeliveriesController#create
  return 422 if member.kindle_email.blank?
  return 422 if book.oversize_for_kindle?    # file_size > 24.megabytes
  delivery = KindleDelivery.create!(status: :pending, member:, book:)
  SendToKindleJob.perform_later(delivery.id)
  render turbo_stream: button "Sending… ⟳"

SendToKindleJob(delivery_id).perform
  path = BookStorage.download(delivery.book.object_key)
  KindleMailer.deliver_book(delivery).deliver_now
  delivery.update!(status: :sent, sent_at: now)
  broadcast turbo_stream: "Sent ✓ — acum"
rescue StandardError => e
  delivery.update!(status: :failed, error: e.message)
  broadcast turbo_stream: "Eșuat — reîncearcă"
  raise          # Solid Queue retry
```

Oversize check at the boundary; UI also disables the button with a tooltip when `book.oversize_for_kindle?` is true.

### 5.3 Mark read / rate

```
PATCH /books/:id/member_book   { rating: "mi_a_placut", read: true }
  MemberBook.find_or_initialize_by(member:, book:)
  assign rating (or nil to un-rate), read_at = read? ? Time.current : nil
  save!
  render turbo_stream: replace rating buttons + read toggle
```

UI: three-button toggle group (one button per rating level). Clicking the active button again clears the rating. Synchronous, no jobs.

### 5.4 Download fallback

```
GET /books/:id/download
  authorize
  redirect_to BookStorage.presigned_url(book.object_key, expires_in: 5.min)
```

Browser pulls directly from object storage; Rails never proxies bytes.

## 6. Error handling

| Failure | Behaviour |
|---|---|
| S3 unreachable during ingest | `IngestBookJob` raises, Solid Queue retries (3x, exponential). Admin status panel shows last successful vs last attempted scan. |
| File download fails mid-stream | `ProcessBookFileJob` retries independently; doesn't block other files in the same scan. |
| Parse failure | Row created with `title = filename, parse_error = <msg>`. Surfaces in admin "Needs metadata". |
| No cover in file | Not an error. UI shows default placeholder. |
| File missing from bucket | `missing_since` set on existing row. Row preserved so ratings/read state survive a re-upload. |
| SMTP error | `KindleDelivery` → `failed`; Solid Queue retries. After 3 attempts, UI shows "Failed — retry". |
| Wrong Kindle email / not on Amazon approved list | Undetectable from our side. UI shows "Sent ✓" linked to a "Troubleshoot" help page. |
| Object storage unreachable on send | Retry path same as ingestion. |
| Wrong password | Rails 8 default. Rack::Attack rate-limits 10 failures / 10 min per IP. |
| Forgot password | Admin-mediated. `Admin::MembersController#send_reset_link` emails a single-use link. No public reset form. |
| Non-admin tries `/admin/*` | 404, not 403. |
| Volume >80% full | `DiskCheckJob` emails admin weekly. |

## 7. Localization (Romanian)

- `I18n.default_locale = :ro`. No locale switcher.
- `rails-i18n` provides Romanian translations for ActiveRecord/ActiveModel/dates.
- All UI copy in `config/locales/ro.yml` from day one. No hardcoded strings in views/controllers.
- `config.time_zone = "Bucharest"`. Recurring jobs use this zone.
- Date format: `dd.mm.yyyy` via `I18n.l`. Relative times via `distance_of_time_in_words` (translated by `rails-i18n`).

**Sort + search:**

SQLite text sort is byte-wise — `Țară` would sort after `Zalău`. Two derived columns on `Book`, populated by a `before_save` callback:

- `sort_title` — `DiacriticFolding.fold(title)` — used as the default catalog sort.
- `searchable` — `DiacriticFolding.fold([title, author, description].compact.join(" "))` — used by the catalog search input. `WHERE searchable LIKE ?`.

```ruby
DIACRITIC_MAP = {
  "ă" => "a", "â" => "a", "î" => "i",
  "ș" => "s", "ş" => "s",
  "ț" => "t", "ţ" => "t",
  "Ă" => "A", "Â" => "A", "Î" => "I",
  "Ș" => "S", "Ş" => "S",
  "Ț" => "T", "Ţ" => "T",
}.freeze
```

Covers both modern (comma-below) and old (cedilla) glyphs.

**Encoding:** UTF-8 end-to-end. `gepub` returns UTF-8; `aws-sdk-s3` keys are UTF-8; SQLite stores UTF-8. The only deliberate departure is the Kindle email subject (ASCII-folded) due to historic Kindle filename behaviour with non-ASCII headers.

**Emails:** Kindle delivery body and all admin/member-facing emails are in Romanian.

**Tests:** at least one parser fixture with Romanian diacritics in title/author; at least one search test asserting `bizant` matches `Bizanț`.

## 8. Testing

Two test surfaces.

### 8.1 Rails (in-repo) — Minitest

Rails 8 default. `bin/rails test` runs the full suite.

- **Models** — validations, `Book#oversize_for_kindle?`, `MemberBook` upsert, `KindleDelivery` state transitions, `Member#admin?`.
- **Services** — `Ebook::EpubParser` and `Ebook::MobiParser` against real fixture files in `test/fixtures/files/ebooks/`: well-tagged EPUB, EPUB without cover, EPUB without metadata, corrupt file, Romanian-diacritic EPUB. `DiacriticFolding.fold` against representative inputs.
- **Jobs** — `IngestBookJob` and `ProcessBookFileJob` with `Aws.config[:stub_responses] = true`. Cover new file, missing file, re-scan no-op, parse failure. `SendToKindleJob` with Action Mailer `:test` adapter.
- **Mailers** — `KindleMailer#deliver_book` asserts attachment name/size/content-type and recipient.
- **Controllers** — happy path plus auth boundaries. Non-admin gets 404 on `/admin/*`; unauthenticated redirects to login.

**No `test/system/` directory.** Browser-driven coverage lives in the Playwright project.

**Stubbing:** AWS SDK stubs, Action Mailer test adapter, `freeze_time`. SQLite test DB is real (transactional fixtures).

### 8.2 Playwright (separate npm project) — `familioteca-e2e/`

TypeScript + Playwright. Boilerplate matches the existing pattern in **livada / apoplodoro / curente** — same `playwright.config.ts` shape, login helpers, and Rails-test-server bootstrap. Inspect one of those projects at plan time and mirror the structure.

MVP flows:

1. Member signs in → opens a book → sends to Kindle → sees "Trimisă ✓".
2. Member selects "Mi-a plăcut" + marks read → reload preserves the state.
3. Admin clicks "Scanează acum" → new book appears in the catalog.

Each test seeds data via a Rails task and runs against `RAILS_ENV=test` with AWS SDK stubs configured via env flag (same convention as sibling projects).

## 9. CI / CD

**CircleCI** — runs tests on every push to any branch:
- `bin/rails test`
- `npm test` in `familioteca-e2e/`

**GitHub Actions** — runs the deploy workflow:
- Trigger: push to `main`
- Calls `fly deploy`
- Gated on CircleCI success (required-check via GitHub, or trusted-by-convention to start)

Split intentionally to fit free tiers on both providers.

`.circleci/config.yml` and `.github/workflows/deploy.yml` adapted from the livada / apoplodoro / curente templates.

## 10. Deployment

- **Fly.io** app with a single machine + mounted volume (`/data`, persistent).
- **`fly.toml`** declares one process group running web, Solid Queue, and Litestream (single-machine deploy; horizontal scale is post-MVP and would require revisiting Litestream since it assumes one writer).
- **Secrets** (Rails master key, Gmail App Password, S3/R2 access keys, Tigris access keys) set via `fly secrets set`.
- **Volume contents**: SQLite DBs and Active Storage local-disk service.

**Backup — Litestream → Tigris:**

- **Litestream** runs as a sidecar process inside the same machine, started by the container entrypoint via `litestream replicate -exec` so it supervises the Rails process. Continuously streams the WAL to Tigris.
- **Tigris** (Fly.io's S3-compatible object storage, native to the platform) holds the replicas. Separate bucket from the ebook bucket; separate credentials.
- **`litestream.yml`** declares all four SQLite files (`familioteca.sqlite3`, `queue.sqlite3`, `cache.sqlite3`, `cable.sqlite3`) as `dbs`, each replicating to a path under the Tigris bucket. The queue/cache/cable DBs are replicated too — cheap, and lets us restore the full machine state, not just app data.
- **Restore on boot**: the entrypoint runs `litestream restore -if-replica-exists` on each DB before launching Rails, so a fresh volume (or recovery to a new machine) hydrates from Tigris automatically.
- **Retention**: configured in `litestream.yml` (default 24h snapshots, 30-day generation retention). Tuned at deploy time.
- **Recovery drill**: documented as a one-command `litestream restore` against a local SQLite path; ideally exercised before launch.

- **Domain**: TBD (Fly subdomain to start; custom domain optional).

## 11. Open items at plan time

These are deferred to the plan, not the spec:

- Inspect livada / apoplodoro / curente repos to confirm exact Playwright + CI config patterns.
- Confirm Cloudflare R2 vs AWS S3 (cost; capability is equivalent for our usage).
- Confirm whether the `mobi` gem is reliable on our actual `.mobi` files, or fall back to filename-only parsing for that format.
- Choose between `tailwindcss-rails` and plain CSS for the UI.

## 12. Stack summary

| Concern | Choice |
|---|---|
| Framework | Ruby on Rails 8 |
| UI | Hotwire / Turbo |
| Database | SQLite (Solid stack: queue, cache, cable) |
| Background jobs | Solid Queue |
| File storage (ebooks) | Object storage (S3 or R2) |
| File storage (covers) | Active Storage on disk volume |
| Database backup | Litestream → Tigris |
| Email | Gmail SMTP (App Password) |
| Auth | Rails 8 built-in (`has_secure_password`) |
| Hosting | Fly.io with mounted volume |
| Locale | Romanian only |
| Rails tests | Minitest (in-repo) |
| Browser tests | Playwright + TypeScript (separate npm project) |
| CI | CircleCI (tests) + GitHub Actions (deploy) |
