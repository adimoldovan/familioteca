# Familioteca — Design System

Direction: **Broadsheet**. Warm paper, editorial serif headlines, mono meta,
terracotta accent, rule-based layout. The reference artboards live in
`docs/design/project/` (exported from Claude Design).

The system is defined in one place: `app/assets/tailwind/application.css`.
Tokens are CSS custom properties on `:root` and `.dark` — flipping `.dark` on
any ancestor re-themes its subtree. Components consume tokens via
`var(--…)` and semantic classes; we don't mirror the palette into Tailwind
`@theme`, since the design uses component classes rather than colour/font
utilities. Tailwind's layout utilities remain available for one-off tweaks.

## Tokens

### Colour (paper + ink)

| Variable | Light | Dark |
| --- | --- | --- |
| `--paper` | `#FAF7F2` | `#16130F` |
| `--paper-2` | `#F3EFE7` | `#1E1A15` |
| `--paper-edge` | `#EAE4D8` | `#2A2520` |
| `--ink` | `#1A1613` | `#F3EEE3` |
| `--ink-2` | `#3D362F` | `#D9D1C2` |
| `--ink-3` | `#6B6259` | `#9C9384` |
| `--ink-4` | `#9A9186` | `#726A5D` |
| `--ink-5` | `#C5BDB1` | `#4A443B` |
| `--rule` | `#E3DDD0` | `#2A2520` |
| `--rule-soft` | `#EDE7DA` | `#211D18` |

Think of `--paper-*` as warm backgrounds and `--ink-*` as a darkness scale
— 1 is strongest, 5 is lightest. Rules are horizontal/vertical divider lines.

### Accent

| Variable | Light | Dark |
| --- | --- | --- |
| `--accent` (terracotta) | `#B4553A` | `#D68465` |
| `--accent-ink` | `#8B3E28` | `#E8A48A` |
| `--accent-wash` | `#F4E5DC` | `#2E1F18` |

Used sparingly: links, current-state indicators, accent rails on callouts.

### Status

| Variable | Light | Dark |
| --- | --- | --- |
| `--ok` | `#5C7A4A` (moss green) | `#7CA860` |
| `--warn` | `#B8863A` (amber) | `#D4A055` |

Dark values lift the lightness to meet WCAG AA contrast on dark paper.

### Font-size scale

| Variable | Value | Role |
| --- | --- | --- |
| `--fs-dot` | 10px | Decorative dots, glyphs, brand meta |
| `--fs-eyebrow` | 10.5px | Mono eyebrow labels, dateline, form labels |
| `--fs-meta` | 11px | Rail items, menu labels, kbd shortcuts |
| `--fs-caption` | 12.5px | Dek, error-summary body, small footer |
| `--fs-body-sm` | 13px | Small body, code, pre |
| `--fs-body` | 14px | Base body |
| `--fs-item` | 15.5px | Entry-row title in list |
| `--fs-lede` | 16px | Lede subtitle, reading content |
| `--fs-lede-lg` | 17px | Large lede, form input |
| `--fs-icon` | 18px | Icon-glyph buttons (kebab trigger) |
| `--fs-modal` | 20px | Modal heading |
| `--fs-title` | 22px | Brand name, close button |
| `--fs-display` | 26px | Display headline (empty state) |
| `--fs-headline` | 32px | Page headline |
| `--fs-hero` | 40px | Hero headline |

### Type families

| Variable | Stack |
| --- | --- |
| `--serif` | `ui-serif` → New York → Iowan Old Style → Palatino → Cambria → Georgia |
| `--sans` | `system-ui` → San Francisco / Segoe UI / Helvetica Neue → Arial |
| `--mono` | `ui-monospace` → SF Mono → Menlo / Consolas / Liberation Mono |

All three stacks are **system fonts only** — no webfont download, no Google
Fonts network dependency, no third-party request on page load. The exact
face will differ between macOS, Windows, and Linux, but the *category*
(editorial serif, UI sans, slab mono) stays consistent. If we later want a
tighter visual match to Source Serif 4 / Inter / JetBrains Mono, we would
self-host them under `app/assets/fonts/` and extend the stack with
`@font-face` — not reintroduce a CDN.

### Spacing

A numeric scale in 4px increments. Use these tokens for any padding, margin,
or gap value — don't reach for raw `rem`s or Tailwind's `var(--spacing-N)`.

| Variable | Value |
| --- | --- |
| `--space-1` | 0.25rem (4px) |
| `--space-2` | 0.5rem (8px) |
| `--space-3` | 0.75rem (12px) |
| `--space-4` | 1rem (16px) |
| `--space-5` | 1.25rem (20px) |
| `--space-6` | 1.5rem (24px) |
| `--space-8` | 2rem (32px) |
| `--space-10` | 2.5rem (40px) |
| `--space-12` | 3rem (48px) |
| `--space-16` | 4rem (64px) |

### Layout

| Variable | Value | Role |
| --- | --- | --- |
| `--layout-max-width` | 64rem | Signed-in page max-width (header bar, main) |
| `--auth-minimal-width` | 460px | Sign-in/sign-up centred column |
| `--auth-frame-inner-width` | 400px | Form column inside `.auth-frame__body` |
| `--flash-min-width` | 280px | Min width of `.flash` toast |
| `--flash-max-width` | 480px | Max width of `.flash` toast |

### Effects

| Variable | Value | Role |
| --- | --- | --- |
| `--shadow-card` | `0 4px 12px rgba(0,0,0,0.08)` light / `(…,0.4)` dark | Floating surfaces (`.flash`, future popovers) |

## Typography

| Class | Use |
| --- | --- |
| `.serif` / `.sans` / `.mono` | Family helpers |
| `.t-eyebrow` | Small mono-caps label above a section ("§ Sign in") |
| `.t-eyebrow--accent` | Modifier — same, coloured terracotta for marker eyebrows |
| `.t-headline` | 32px serif page heading (`--fs-headline`) |
| `.t-headline--xl` | 40px variant for landing hero (`--fs-hero`) |
| `.t-lede` | Italic serif subtitle paragraph |
| `.t-lede--lg` | 17px variant |

Headlines use negative letter-spacing (`-0.7px`) to tighten for display
sizes. Ledes are italic serif to contrast the upright ink of body copy.

## Components

All component classes are in `app/assets/tailwind/application.css`. Don't
reach for Tailwind utilities to re-build these — use the class, and add a
new class in `application.css` for any layout tweak. Inline `style="…"` is
not allowed (see [STYLE.md](../STYLE.md)).

### Buttons

```erb
<%= form.submit "Sign in", class: "btn btn-primary" %>
<%= link_to "Sign in", new_session_path, class: "btn btn-secondary" %>
```

- `.btn-primary` — inked background, paper text, full-width by default
- `.btn-secondary` — transparent, ruled border, hover darkens

### Form fields (underline style)

```erb
<div class="form-field">
  <div class="form-field__header">
    <label for="user_email_address" class="form-field__label">Email address</label>
  </div>
  <%= f.email_field :email_address, id: "user_email_address", class: "form-field__input", ... %>
  <div class="form-field__hint">Optional hint below.</div>
</div>
```

Fields use a bottom border only (no box), serif input text, mono eyebrow
label. Focus moves the border to `--accent`. Form-wide validation errors are
surfaced via `.error-summary` at the top of the form (see below), not per
field — the single summary keeps the visual noise down.

Use a `<div>` wrapper with an explicit `<label for="…">` (rather than
wrapping the input in a `<label>`). Implicit labelling breaks when the
header row also contains an interactive element like a "Forgot?" link —
`<a>` inside `<label>` is invalid HTML.

Single-line inline errors (e.g. authentication failures, where there's one
message rather than a list) render as `<p class="flash-error">`. Mono
caption text in `--accent-ink`. Use `.error-summary` (below) when surfacing
per-field validation failures.

### Flash messages

Rendered automatically by `shared/_flash` from the layout. Appears fixed at
top-centre. Levels: `notice` (ok-green rail), `alert` (accent rail). Unknown
flash keys are rendered as `alert` (the defensive fallback). The partial
intentionally skips `:error` — those are rendered inline by views (see
`flash-error` above) so the user sees the message next to the form they
failed.

Controller code stays standard Rails:

```ruby
redirect_to new_session_path, notice: "Password has been reset"
```

Multiple simultaneous flash messages stack visually at the same fixed
position; the current usage is one message at a time. If a flow ever fires
both `:notice` and `:alert` in the same response, add a stacking offset to
the component.

### Error summary (inline form errors)

Visually similar to `flash--alert` but with its own contract: renders
*inline* in the document flow, not as a fixed overlay. Use it for per-form
validation summaries.

```erb
<div class="error-summary" role="alert">
  <div class="error-summary__title">2 errors prevented sign-up</div>
  <ul class="error-summary__list">
    <% @user.errors.full_messages.each do |msg| %>
      <li><%= msg %></li>
    <% end %>
  </ul>
</div>
```

### Auth minimal (single-column)

Used by **sign-in and sign-up**. A stripped layout — no editorial aside, no
footer, no eyebrows. Just brand, nav link, headline, form.

```erb
<main class="auth-minimal" aria-label="Sign in">
  <div class="auth-minimal__nav">
    <%= link_to "Familioteca", root_path, class: "brand__name" %>
    <div class="auth-frame__topbar-meta">
      No account? <%= link_to "Sign up", sign_up_path, class: "link-accent" %>
    </div>
  </div>

  <h1 class="t-headline">Welcome back.</h1>
  <%# form… %>
</main>
```

- Fixed max-width (460px), centred.
- The aside, stat-strip, dateline, and editorial eyebrow are deliberately
  absent — they belong on landing / marketing surfaces, not on return
  actions.

### Auth frame (split layout)

Used by password-reset and the guest home. Structure:

```erb
<main class="auth-frame">
  <%= render "shared/auth_aside" %>

  <section class="auth-frame__body" aria-label="Sign in">
    <div class="auth-frame__topbar">
      <span class="t-eyebrow">…</span>
      <div class="auth-frame__topbar-meta">Have an account? <a class="link-accent">Sign in</a></div>
    </div>
    <div class="auth-frame__body-content">…</div>
    <%= render "shared/auth_footer" %>
  </section>
</main>
```

- `auth-frame` — CSS grid `1fr 1.15fr`, stacks below 900px. The outer
  element is `<main>` and the right section carries an `aria-label` for
  landmark navigation.
- `auth-frame__aside` — paper-2, editorial headline + lede, dateline
- `auth-frame__body` — paper, form column with centred 400px inner
- `auth-frame__topbar-meta` — small mono-sans right-side nav link
- `auth-frame__footer` — mono meta at the bottom

### Dateline

`dateline` renders `[ left mono · horizontal rule · right mono ]`. Used in the
aside footer.

### Brand

Static (e.g. auth aside):

```erb
<div class="brand">
  <%= image_tag "/icon.png", alt: "", class: "brand__icon" %>
  <span class="brand__name">Familioteca</span>
</div>
```

As a link (e.g. library rail, sign-in nav):

```erb
<%= link_to root_path, class: "brand" do %>
  <%= image_tag "/icon.png", alt: "", class: "brand__icon" %>
  <span class="brand__name">Familioteca</span>
  <span class="brand__beta">Beta</span>
<% end %>
```

`brand__icon` — 24×24px logo mark (decorative; adjacent text already labels it). `brand__name` — serif wordmark. `brand__beta` is an accent-wash pill flagging the app's beta status, rendered alongside the wordmark in the link partial and hidden on the collapsed library rail.

### Library rail badge

Unread count rendered at the right edge of each `.library-rail__item`. Mono
11px, `--ink-4`; the active row flips it to `--accent`. Hidden entirely when
the count is zero — the column only appears when it has a signal to carry.

```erb
<li class="library-rail__item">
  <span class="library-rail__glyph">S</span>
  <a class="library-rail__name library-rail__link">Slowfold</a>
  <span class="library-rail__badge">7</span>
</li>
```

### Rules

- `.rule-fill` — horizontal divider that expands to fill remaining flex space (used in the dateline)

### Data table

Plain editorial table for admin views (member list, future audit logs).
Mono eyebrow headers, sans-serif body cells, hairline `--rule-soft` row
separators. No zebra stripes — the rules carry the rhythm.

```erb
<table class="data-table" aria-labelledby="members-heading">
  <thead>
    <tr>
      <th scope="col">Nume</th>
      <th scope="col">Email</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>Ana</td><td>ana@example.com</td></tr>
  </tbody>
</table>
```

### Empty state

Used when a collection view (catalog, future shelf views) has nothing to
display. Big serif display headline + italic serif lede, centred, with
generous vertical breathing room (`--space-16`).

```erb
<div class="empty-state">
  <h1 class="empty-state__title">Bibliotecă</h1>
  <p class="empty-state__body">Niciun titlu disponibil</p>
</div>
```

### Theme toggle

Single icon-button that flips `.dark` on `<html>` and persists the choice
to `localStorage` under the key `theme` (`light` / `dark`). On first visit
with no stored preference, the system's `prefers-color-scheme` decides.
Rendered from `shared/_theme_toggle` in both the site header and the
`.auth-minimal__nav`. FOUC is prevented by an inline `<script>` in
`application.html.erb` that reads `localStorage` and applies the class
before the body parses.

```erb
<%= render "shared/theme_toggle" %>
```

## Dark mode

Toggle by adding the `.dark` class on `<html>` or any ancestor. All tokens
re-resolve. No separate component classes needed.

The UI toggle lives in `app/views/shared/_theme_toggle.html.erb` and is
backed by the Stimulus controller `app/javascript/controllers/theme_controller.js`.
See the *Theme toggle* component above.

## Adding to the system

1. New token → add it on both `:root` and `.dark` in
   `app/assets/tailwind/application.css`. Mirror it in `@theme` only if you
   want a Tailwind utility generated.
2. New component → define a BEM-style class (`.foo`, `.foo__part`,
   `.foo--mod`) in the same file. Don't inline the styles in a view.
3. Document it here under the matching section.

Rules of thumb:
- Prefer tokens over raw hex.
- Prefer semantic classes over Tailwind utility soup once a pattern repeats.
- Never use inline `style="…"` — define a class in `application.css` instead.
  See [STYLE.md](../STYLE.md).
