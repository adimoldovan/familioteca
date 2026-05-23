# Operations

## Deployment

Hosted on Fly.io (region: `ams`). SQLite databases live on a persistent volume mounted at `/rails/storage`. CI runs on CircleCI; GitHub Actions auto-deploys to Fly.io after CI passes on `main`. Manual deploy: `fly deploy`.

Key files:
- [`fly.toml`](../fly.toml) — Fly.io app config (shared-cpu-1x, 1024MB, always running)
- [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) — auto-deploy workflow
- [`Dockerfile`](../Dockerfile) — production image using Thruster on port 8080

## Updating app icons

When the brand icon changes, **rename the icon files to a new path** (not just bump the `?v=` query string). iOS Safari keeps a separate webclip icon cache that survives "Clear History and Website Data" and ignores query strings on `apple-touch-icon`. A new URL path is the only reliable way to bust it.

### Files to update

- `public/apple-touch-icon-vN.png` — used by iOS home‑screen webclip. Source of truth for the iOS icon.
- `public/icon-192-vN.png`, `public/icon-512-vN.png` — referenced by [`app/views/pwa/manifest.json.erb`](../app/views/pwa/manifest.json.erb). Used by Android/Chrome PWA install. iOS does **not** read manifest icons for the home screen.
- `public/icon.png` — favicon (browser tab) and in‑app brand mark. The `?v=N` query string is enough here; favicons aren't subject to the iOS webclip cache.

References to bump in lockstep:
- [`app/views/layouts/application.html.erb`](../app/views/layouts/application.html.erb) — `<link rel="apple-touch-icon">` and `<link rel="icon">`.
- [`app/views/pwa/manifest.json.erb`](../app/views/pwa/manifest.json.erb) — three `icons[].src` entries.

### Procedure

1. Generate the new PNGs and place them in `public/` with a bumped `-vN` suffix. Keep the old files in place — crawlers and old caches still probe the conventional `apple-touch-icon.png` path.
2. Update the references above to point at the new filenames. Bump `?v=` on the favicon and brand mark for consistency.
3. Deploy.
4. **On iOS, delete the existing home‑screen icon before re‑adding** (long‑press → Delete from Home Screen). Without this step, the webclip keeps the old icon even after deploy. Clearing Safari data alone does not clear the webclip cache.
5. Open the site fresh in Safari → Share → Add to Home Screen. The new path bypasses every cache layer.

### Why query strings don't work

Production serves everything in `public/` with `cache-control: public, max-age=1.year` (see [`config/environments/production.rb`](../config/environments/production.rb)). Browsers and intermediaries hold the file for a year. Favicons get refetched when the `<link>` URL changes (query string included), but iOS's webclip image cache is keyed by path alone — so `apple-touch-icon.png?v=N` and `apple-touch-icon.png?v=N+1` collide.

## Environment variables

Set in production via `fly secrets set` (or, for `FLY_API_TOKEN`, as a GitHub Actions secret).

### Application

| Variable | Required | Default | Description |
|---|---|---|---|
| `FAMILIOTECA_FROM_EMAIL` | **yes** | — | Sender address for all outgoing email |
| `FAMILIOTECA_GMAIL_USER` | production, dev | — | Gmail address for SMTP authentication |
| `FAMILIOTECA_GMAIL_APP_PASSWORD` | production, dev | — | Gmail app-specific password for SMTP |
| `FAMILIOTECA_HOST` | no | `familioteca.fly.dev` | Host for URLs generated in mailer templates |
| `FAMILIOTECA_BUCKET_ENDPOINT` | production | — | S3-compatible endpoint URL for book storage |
| `FAMILIOTECA_BUCKET_NAME` | production | `familioteca-{env}` | Bucket name for book storage |
| `FAMILIOTECA_BUCKET_KEY_ID` | production | — | S3 access key ID |
| `FAMILIOTECA_BUCKET_SECRET` | production | — | S3 secret access key |
| `FAMILIOTECA_BUCKET_REGION` | no | `auto` | S3 bucket region |

### Seeding

Used by `db:seed` to create the initial admin account. In dev/test these have defaults; in production `FAMILIOTECA_ADMIN_PASSWORD` is required.

| Variable | Default (dev/test) |
|---|---|
| `FAMILIOTECA_ADMIN_EMAIL` | `admin@familioteca.local` |
| `FAMILIOTECA_ADMIN_PASSWORD` | `changeme123` |
| `FAMILIOTECA_ADMIN_NAME` | `Administrator` |

### Rails / server tuning

| Variable | Default | Description |
|---|---|---|
| `RAILS_MASTER_KEY` | — | Decrypts `config/credentials.yml.enc` |
| `RAILS_ENV` | `development` | Rails environment |
| `RAILS_LOG_LEVEL` | `info` (production) | Log verbosity |
| `RAILS_MAX_THREADS` | `3` | Puma threads; also sizes the DB connection pool |
| `PORT` | `3000` | Puma listen port |
| `WEB_CONCURRENCY` | `1` | Puma worker processes |
| `JOB_CONCURRENCY` | `1` | Solid Queue worker processes |
| `SOLID_QUEUE_IN_PUMA` | — | When set, runs Solid Queue inside Puma |
| `PIDFILE` | — | Custom PID file path for Puma |

### Infrastructure / deploy

| Variable | Description |
|---|---|
| `FLY_API_TOKEN` | GitHub Actions secret for `fly deploy` |
| `AWS_ENDPOINT_URL_S3` | Tigris endpoint for Litestream replication |
| `BUCKET_NAME` | Tigris bucket for Litestream |
| `AWS_ACCESS_KEY_ID` | Tigris access key |
| `AWS_SECRET_ACCESS_KEY` | Tigris secret key |
| `AWS_REGION` | Tigris region |

The five `AWS_*` / `BUCKET_NAME` vars are for Litestream SQLite replication only — book storage uses the `FAMILIOTECA_BUCKET_*` vars above. Provision Litestream credentials with `fly storage create`, which sets all five secrets on the app automatically.

## Backup & Restore

Production SQLite databases live on a Fly volume mounted at `/rails/storage` and are continuously replicated to a Tigris (S3-compatible) bucket via Litestream. The replica config is in `config/litestream.yml`; the entrypoint wires Litestream into the app boot when `AWS_ENDPOINT_URL_S3` is non-empty.

Databases replicated:
- `production.sqlite3` — app data
- `production_queue.sqlite3` — Solid Queue
- `production_cache.sqlite3` — Solid Cache
- `production_cable.sqlite3` — Action Cable

### Restore locally

Fast loop for verifying replicas are healthy and rehearsing the procedure without touching Fly. Run this any time you change Litestream config or want to sanity-check the bucket.

1. **Install Litestream.** Match the version pinned in [`Dockerfile`](../Dockerfile):
   ```
   brew install benbjohnson/litestream/litestream
   litestream version
   ```

2. **Export Tigris creds.** Pull them off the Fly app once. Use the `.env.litestream` filename — the project's `.gitignore` has `/.env*` rooted at the repo root, which covers `.env.*` files but **not** other names like `.litestream.env`. Keep the filename and location (repo root) as written:
   ```
   fly ssh console -a familioteca -C env | grep -E '^(AWS_|BUCKET_NAME)=' > .env.litestream
   set -a && source .env.litestream && set +a
   ```

3. **Confirm replicas are fresh** (skip if you just want any restore):
   ```
   for db in production production_queue production_cache production_cable; do
     echo "== $db =="
     litestream snapshots -config config/litestream.yml /rails/storage/$db.sqlite3 | tail -3
   done
   ```
   The `/rails/storage/...` path is the config-key, not a real local path — Litestream looks it up in `config/litestream.yml`. Don't create a `/rails/storage/` directory locally. The newest snapshot timestamp should be within the last 10 minutes for an active app.

4. **Restore into a scratch dir:**
   ```
   mkdir -p tmp/restore
   for db in production production_queue production_cache production_cable; do
     litestream restore -config config/litestream.yml \
       -o tmp/restore/$db.sqlite3 \
       /rails/storage/$db.sqlite3
   done
   ```

5. **Verify row counts** with `sqlite3` against the restored DBs.

6. **Optional — boot Rails read-only against the restored DBs** to confirm the app actually starts and serves a request. Do this in a separate worktree so you don't disturb your dev DBs, and **unset `AWS_ENDPOINT_URL_S3`** before booting so Litestream does not start replicating your local copy back to the bucket:
   ```
   cp tmp/restore/*.sqlite3 storage/
   AWS_ENDPOINT_URL_S3= RAILS_ENV=production \
     RAILS_MASTER_KEY=$(cat config/master.key) \
     bin/rails server -p 3005
   ```
   Visit `http://localhost:3005/up`, log in. Then delete the copied files.

### Restore drill: fresh Fly Machine

Run end-to-end at least once per major release. This proves we can recover the live app from Tigris alone, not just inspect the data.

The drill runs in a **dedicated `familioteca-restore` Fly app**, not in the live `familioteca` app. This is the only safe option: in `familioteca`, `AWS_ENDPOINT_URL_S3` is set as a Fly secret, and Fly secrets win over `--env` flags at `fly machine run` time. A drill machine in the live app would inherit those secrets and the entrypoint would start `litestream replicate` against the live bucket — racing the real replicator and risking replica corruption. A separate app inherits nothing.

1. **Capture a baseline.** Run the local restore above and record row counts plus the live image tag:
   ```
   fly status -a familioteca | grep -i image
   ```

2. **One-time setup — create the drill app:**
   ```
   fly apps create familioteca-restore --org <your-org>
   fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)" -a familioteca-restore
   ```
   Do **not** set Tigris secrets on this app. We'll inject them per-drill, only into the SSH session that runs `litestream restore`, then drop them so the rails server boots without them.

3. **Provision a throwaway volume + machine in `ams`.** Match the volume size to the live volume `familioteca_data` (check `fly volume list -a familioteca`). Bypass the entrypoint entirely with `--entrypoint /bin/sleep` and pass `infinity` as the CMD positional argument:
   ```
   fly volume create familioteca_restore --region ams --size 3 --yes -a familioteca-restore
   fly machine run registry.fly.io/familioteca:<image-tag> infinity \
       --region ams \
       --volume familioteca_restore:/rails/storage \
       --entrypoint /bin/sleep \
       -a familioteca-restore
   ```

4. **SSH in and restore:**
   ```
   fly ssh console -a familioteca-restore -m <new-machine-id>
   ```
   Inside the container — export the Tigris creds for this shell only, restore, then unset:
   ```
   export AWS_ENDPOINT_URL_S3=... AWS_ACCESS_KEY_ID=... \
          AWS_SECRET_ACCESS_KEY=... AWS_REGION=... BUCKET_NAME=...
   time for db in production production_queue production_cache production_cable; do
     litestream restore -config /rails/config/litestream.yml /rails/storage/$db.sqlite3
   done
   unset AWS_ENDPOINT_URL_S3 AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION BUCKET_NAME
   ```

5. **Apply any pending migrations and start Rails manually:**
   ```
   cd /rails
   bin/rails db:migrate
   bin/rails server -p 8080
   ```

6. **Smoke checks.** Reach the machine through `fly proxy 8080:8080 -a familioteca-restore` from your laptop; open the app and confirm row counts match the baseline.

7. **Tear down:**
   ```
   fly machine destroy --force <new-machine-id> -a familioteca-restore
   fly volume destroy <volume-id> -a familioteca-restore
   ```
   Leave the `familioteca-restore` app in place for the next drill — it has no machines and costs nothing while idle.

### Gotchas

- **Never run the drill inside the `familioteca` app.** Fly secrets (including `AWS_ENDPOINT_URL_S3`) win over `--env` flags at `fly machine run` time. A drill machine in `familioteca` would inherit the live Tigris creds, the entrypoint would start `litestream replicate -exec`, and the replicator would race the live one — risking replica corruption. Always use a separate `familioteca-restore` app.
- **Bypass the entrypoint, don't just override the CMD.** Use `--entrypoint /bin/sleep` plus `infinity` as the CMD positional argument. If you only override the CMD, the app's entrypoint still runs and could fire Litestream replication if any Tigris-related env var were ever set on the drill app.
- **Volume size must equal or exceed prod.** `auto_extend_size_*` in `fly.toml` only grows the live volume; a throwaway volume starts at whatever you pass to `fly volume create`.
- **WAL checkpointing lag.** Litestream replicates the SQLite WAL incrementally; the last few seconds of writes may not be in the replica yet. Use `litestream snapshots` to confirm freshness before treating a restore as authoritative.
- **Pin the Litestream version.** Local Litestream must match the Dockerfile pin. `brew install` follows the tap and may give a newer release — verify with `litestream version`.
- **Tigris cred file naming.** `.gitignore` has `/.env*` rooted at the repo root. That covers `.env.litestream` but **not** other names like `.litestream.env`, which would slip past gitignore and could be committed. Stick with the `.env.<suffix>` shape and keep the file at the repo root.
