# Familioteca — Phase 1: Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Rails 8 app skeleton — Romanian locale, Member authentication, login + logout, an empty "catalog" page, and an admin-only members index. After this phase the app does not yet read any books; it lets you sign in and lands on an "Niciun titlu disponibil" page.

**Architecture:** Rails 8 monolith with Hotwire/Turbo, SQLite (default Rails 8 with Solid Queue/Cache/Cable databases), Tailwind for styling. Authentication is hand-written using `has_secure_password` and a `Session` model. Romanian is the only locale, configured at the app level.

**Tech Stack:** Ruby 3.3+, Rails 8, SQLite 3, Tailwind CSS via `tailwindcss-rails`, Minitest, `rails-i18n`, `rack-attack`, `bcrypt`.

**Working directory for all tasks:** `~/code/ghcom/adimoldovan/familioteca`

---

## File Structure (after Phase 1)

```
~/code/ghcom/adimoldovan/familioteca/
├── Gemfile                                  # rails-i18n + rack-attack added
├── README.md
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb        # includes Authentication
│   │   ├── books_controller.rb              # #index (empty placeholder)
│   │   ├── sessions_controller.rb           # #new, #create, #destroy
│   │   ├── concerns/
│   │   │   └── authentication.rb            # current_member, require_login, require_admin
│   │   └── admin/
│   │       ├── base_controller.rb           # require_admin (404 if not)
│   │       └── members_controller.rb        # #index
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── member.rb                        # has_secure_password, has_many :sessions
│   │   └── session.rb                       # belongs_to :member, token
│   ├── services/
│   │   └── diacritic_folding.rb             # fold(string) — strips Romanian diacritics
│   └── views/
│       ├── layouts/
│       │   └── application.html.erb         # Romanian nav, sign-out
│       ├── sessions/
│       │   └── new.html.erb                 # login form in Romanian
│       ├── books/
│       │   └── index.html.erb               # empty-state in Romanian
│       └── admin/members/
│           └── index.html.erb               # table of members
├── config/
│   ├── application.rb                       # locale = :ro, time_zone = Bucharest
│   ├── routes.rb
│   ├── locales/
│   │   ├── en.yml                           # left empty (we don't use English)
│   │   └── ro.yml                           # all UI copy
│   └── initializers/
│       └── rack_attack.rb                   # login rate limit
├── db/
│   ├── migrate/
│   │   ├── …_create_members.rb
│   │   └── …_create_sessions.rb
│   ├── schema.rb
│   └── seeds.rb                             # first admin member
└── test/
    ├── controllers/
    │   ├── books_controller_test.rb
    │   ├── sessions_controller_test.rb
    │   └── admin/
    │       └── members_controller_test.rb
    ├── models/
    │   ├── member_test.rb
    │   └── session_test.rb
    ├── services/
    │   └── diacritic_folding_test.rb
    ├── integration/
    │   └── rack_attack_test.rb
    └── test_helper.rb
```

**Boundary notes:**
- `Authentication` concern is the single source of truth for "who is logged in" and "is this allowed." Controllers don't reach into session details directly.
- `DiacriticFolding` is a pure function service. It lives in `app/services/` because §4 of the spec puts service POROs there.
- `Admin::BaseController` is the *only* controller that enforces admin. `Admin::*` controllers inherit from it. Non-admin controllers never need admin checks.

---

## Task 0: Project scaffold

**Files:**
- Create: `~/code/ghcom/adimoldovan/familioteca/` (whole Rails app)

No tests for this task — pure scaffolding. The verification is that the dev server boots.

- [ ] **Step 1: Create parent directory and verify Ruby/Rails versions**

Run:
```bash
mkdir -p ~/code/ghcom/adimoldovan
cd ~/code/ghcom/adimoldovan
ruby -v       # expect 3.3.x or newer
gem list rails -i -v "~> 8.0"   # expect "true" — install if not
```

If Rails 8 is not installed:
```bash
gem install rails -v "~> 8.0"
```

- [ ] **Step 2: Generate the Rails 8 app**

Run:
```bash
cd ~/code/ghcom/adimoldovan
rails new familioteca \
  --database=sqlite3 \
  --css=tailwind \
  --skip-jbuilder \
  --skip-action-mailbox \
  --skip-action-text
```

This creates `~/code/ghcom/adimoldovan/familioteca/` populated with Rails 8 defaults (Hotwire/Turbo, Solid Queue, Solid Cache, Solid Cable, Tailwind, SQLite for app + queue + cache + cable).

Expected: command finishes with `bundle install` running successfully and Tailwind assets generated.

- [ ] **Step 3: Verify the app boots**

Run:
```bash
cd ~/code/ghcom/adimoldovan/familioteca
bin/rails db:prepare
bin/dev &
sleep 5
curl -sI http://localhost:3000 | head -1
kill %1
```

Expected: `HTTP/1.1 200 OK` (the default Rails welcome page).

- [ ] **Step 4: Initial commit**

The `rails new` command runs `git init` and creates an initial commit automatically. Verify:
```bash
cd ~/code/ghcom/adimoldovan/familioteca
git log --oneline
```

Expected: one commit, "Initial commit" (or similar from Rails 8 generator).

If there's no commit:
```bash
git add -A
git commit -m "Initial Rails 8 scaffold"
```

---

## Task 1: Add base gems

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Uncomment `bcrypt`**

Rails 8 ships `bcrypt` in the Gemfile but commented out. Open `Gemfile` and find the line:

```ruby
# gem "bcrypt", "~> 3.1.7"
```

Remove the `# ` prefix so it reads:

```ruby
gem "bcrypt", "~> 3.1.7"
```

This is required because Task 5 uses `has_secure_password`, which needs `bcrypt`.

- [ ] **Step 2: Add `rails-i18n` and `rack-attack` to Gemfile**

In the same `Gemfile`, append these two lines after the main framework gems (not inside any `group` block):

```ruby
gem "rails-i18n", "~> 8.0"
gem "rack-attack", "~> 6.7"
```

- [ ] **Step 3: Install**

Run:
```bash
bundle install
```

Expected: gems install successfully. `Gemfile.lock` is updated.

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Enable bcrypt and add rails-i18n + rack-attack gems"
```

---

## Task 2: Configure Romanian locale + Bucharest timezone

**Files:**
- Modify: `config/application.rb`
- Test: `test/integration/locale_config_test.rb` (new file)

- [ ] **Step 1: Write the failing test**

Create `test/integration/locale_config_test.rb`:

```ruby
require "test_helper"

class LocaleConfigTest < ActiveSupport::TestCase
  test "default locale is Romanian" do
    assert_equal :ro, I18n.default_locale
  end

  test "available locales include :ro" do
    assert_includes I18n.available_locales, :ro
  end

  test "time zone is Bucharest" do
    assert_equal "Bucharest", Time.zone.name
  end
end
```

- [ ] **Step 2: Run the test and verify failure**

Run:
```bash
bin/rails test test/integration/locale_config_test.rb
```

Expected: 3 failures — default locale is `:en`, available locales doesn't include `:ro`, time zone is UTC.

- [ ] **Step 3: Update `config/application.rb`**

Open `config/application.rb`. Inside `class Application < Rails::Application`, add:

```ruby
config.i18n.default_locale = :ro
config.i18n.available_locales = [:ro]
config.i18n.fallbacks = [:ro]
config.time_zone = "Bucharest"
```

- [ ] **Step 4: Run the test and verify pass**

Run:
```bash
bin/rails test test/integration/locale_config_test.rb
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add config/application.rb test/integration/locale_config_test.rb
git commit -m "Configure Romanian locale and Bucharest timezone"
```

---

## Task 3: Add base `ro.yml`

**Files:**
- Create: `config/locales/ro.yml`
- Test: `test/integration/locale_keys_test.rb` (new file)

- [ ] **Step 1: Write the failing test**

Create `test/integration/locale_keys_test.rb`:

```ruby
require "test_helper"

class LocaleKeysTest < ActiveSupport::TestCase
  test "app name resolves in Romanian" do
    assert_equal "Familioteca", I18n.t("app.name")
  end

  test "sign-in keys exist" do
    assert_equal "Autentificare", I18n.t("sessions.new.title")
    assert_equal "Email", I18n.t("sessions.new.email")
    assert_equal "Parolă", I18n.t("sessions.new.password")
    assert_equal "Intră în cont", I18n.t("sessions.new.submit")
  end

  test "sign-out key exists" do
    assert_equal "Deconectare", I18n.t("sessions.destroy.link")
  end

  test "empty catalog key exists" do
    assert_equal "Niciun titlu disponibil", I18n.t("books.index.empty")
  end
end
```

- [ ] **Step 2: Run the test and verify failure**

Run:
```bash
bin/rails test test/integration/locale_keys_test.rb
```

Expected: all 4 tests fail with `translation missing` errors.

- [ ] **Step 3: Create `config/locales/ro.yml`**

Replace the contents of `config/locales/en.yml` (leave it minimal — we don't use it) and create `config/locales/ro.yml`:

```yaml
ro:
  app:
    name: "Familioteca"
    tagline: "Biblioteca de cărți a familiei"

  sessions:
    new:
      title: "Autentificare"
      email: "Email"
      password: "Parolă"
      submit: "Intră în cont"
      invalid: "Email sau parolă greșite."
    destroy:
      link: "Deconectare"

  books:
    index:
      title: "Bibliotecă"
      empty: "Niciun titlu disponibil"

  admin:
    members:
      index:
        title: "Membri"
        name: "Nume"
        email: "Email"
        kindle_email: "Email Kindle"
        role: "Rol"
        admin: "Administrator"
        member: "Membru"

  navigation:
    catalog: "Bibliotecă"
    admin: "Administrare"
```

- [ ] **Step 4: Run the test and verify pass**

Run:
```bash
bin/rails test test/integration/locale_keys_test.rb
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add config/locales/ro.yml test/integration/locale_keys_test.rb
git commit -m "Add Romanian locale file with base translations"
```

---

## Task 4: `DiacriticFolding` service

**Files:**
- Create: `app/services/diacritic_folding.rb`
- Test: `test/services/diacritic_folding_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/diacritic_folding_test.rb`:

```ruby
require "test_helper"

class DiacriticFoldingTest < ActiveSupport::TestCase
  test "folds modern Romanian diacritics" do
    assert_equal "asa si asa", DiacriticFolding.fold("așa și așa")
    assert_equal "bizant", DiacriticFolding.fold("Bizanț")
    assert_equal "tara", DiacriticFolding.fold("Țară")
    assert_equal "inceput", DiacriticFolding.fold("Început")
    assert_equal "carti", DiacriticFolding.fold("cărți")
    assert_equal "manastire", DiacriticFolding.fold("Mănăstire")
  end

  test "folds old-style cedilla forms (ş ţ)" do
    assert_equal "asa", DiacriticFolding.fold("aşa")
    assert_equal "tara", DiacriticFolding.fold("Ţară")
  end

  test "leaves ASCII text unchanged except case" do
    assert_equal "hello world", DiacriticFolding.fold("Hello World")
  end

  test "handles nil and empty string" do
    assert_nil DiacriticFolding.fold(nil)
    assert_equal "", DiacriticFolding.fold("")
  end
end
```

- [ ] **Step 2: Run the test and verify failure**

Run:
```bash
bin/rails test test/services/diacritic_folding_test.rb
```

Expected: failure — `uninitialized constant DiacriticFolding`.

- [ ] **Step 3: Implement the service**

Create `app/services/diacritic_folding.rb`:

```ruby
module DiacriticFolding
  MAP = {
    "ă" => "a", "â" => "a", "î" => "i",
    "ș" => "s", "ş" => "s",
    "ț" => "t", "ţ" => "t",
    "Ă" => "A", "Â" => "A", "Î" => "I",
    "Ș" => "S", "Ş" => "S",
    "Ț" => "T", "Ţ" => "T"
  }.freeze

  PATTERN = Regexp.union(MAP.keys).freeze

  def self.fold(string)
    return nil if string.nil?
    string.gsub(PATTERN, MAP).downcase
  end
end
```

- [ ] **Step 4: Run the test and verify pass**

Run:
```bash
bin/rails test test/services/diacritic_folding_test.rb
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/diacritic_folding.rb test/services/diacritic_folding_test.rb
git commit -m "Add DiacriticFolding service for Romanian text normalization"
```

---

## Task 5: `Member` model + migration

**Files:**
- Create: `db/migrate/<ts>_create_members.rb`
- Create: `app/models/member.rb`
- Test: `test/models/member_test.rb`
- Modify: `test/fixtures/members.yml` (generated)

- [ ] **Step 1: Generate the migration and model file**

Run:
```bash
bin/rails generate model Member \
  email:string:uniq \
  password_digest:string \
  name:string \
  kindle_email:string \
  admin:boolean
```

This creates the migration, an empty `app/models/member.rb`, a fixture file, and a test file. Open the generated migration and edit it so the columns have proper defaults and constraints:

Edit `db/migrate/<timestamp>_create_members.rb`:

```ruby
class CreateMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :members do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.string :kindle_email
      t.boolean :admin, null: false, default: false

      t.timestamps
    end

    add_index :members, :email, unique: true
  end
end
```

- [ ] **Step 2: Run the migration**

Run:
```bash
bin/rails db:migrate
```

Expected: migration runs successfully. `db/schema.rb` updated.

- [ ] **Step 3: Write the failing model test**

Replace the contents of `test/models/member_test.rb` with:

```ruby
require "test_helper"

class MemberTest < ActiveSupport::TestCase
  test "valid member can be created" do
    member = Member.new(
      email: "ana@example.com",
      password: "secret123",
      name: "Ana"
    )
    assert member.valid?, member.errors.full_messages.inspect
  end

  test "admin defaults to false" do
    member = Member.create!(
      email: "ana@example.com",
      password: "secret123",
      name: "Ana"
    )
    assert_equal false, member.admin?
  end

  test "kindle_email is optional" do
    member = Member.new(
      email: "ana@example.com",
      password: "secret123",
      name: "Ana"
    )
    assert member.valid?
  end

  test "password is hashed via has_secure_password" do
    member = Member.create!(
      email: "ana@example.com",
      password: "secret123",
      name: "Ana"
    )
    refute_equal "secret123", member.password_digest
    assert member.authenticate("secret123")
    refute member.authenticate("wrong")
  end
end
```

Also wipe the auto-generated fixtures so they don't conflict. Replace `test/fixtures/members.yml` with:

```yaml
ana:
  email: ana@example.com
  password_digest: <%= BCrypt::Password.create("secret123") %>
  name: Ana
  admin: false

admin:
  email: admin@example.com
  password_digest: <%= BCrypt::Password.create("admin1234") %>
  name: Administrator
  admin: true
```

- [ ] **Step 4: Run the test and verify failure**

Run:
```bash
bin/rails test test/models/member_test.rb
```

Expected: failures — `has_secure_password` not declared, no validations.

- [ ] **Step 5: Implement the model**

Replace `app/models/member.rb` with:

```ruby
class Member < ApplicationRecord
  has_secure_password
end
```

- [ ] **Step 6: Run the test and verify pass**

Run:
```bash
bin/rails test test/models/member_test.rb
```

Expected: 4 tests pass.

- [ ] **Step 7: Commit**

```bash
git add db/migrate db/schema.rb app/models/member.rb test/models/member_test.rb test/fixtures/members.yml
git commit -m "Add Member model with has_secure_password"
```

---

## Task 6: `Member` validations

**Files:**
- Modify: `app/models/member.rb`
- Modify: `test/models/member_test.rb`

- [ ] **Step 1: Write the failing validation tests**

Append to `test/models/member_test.rb` (inside the `class` block, before `end`):

```ruby
test "email is required" do
  member = Member.new(password: "secret123", name: "Ana")
  refute member.valid?
  assert_includes member.errors[:email], "can't be blank"
end

test "email must be unique" do
  Member.create!(email: "ana@example.com", password: "secret123", name: "Ana")
  duplicate = Member.new(email: "ana@example.com", password: "secret123", name: "Other")
  refute duplicate.valid?
  assert_includes duplicate.errors[:email], "has already been taken"
end

test "email must match a basic email format" do
  member = Member.new(email: "not-an-email", password: "secret123", name: "Ana")
  refute member.valid?
  assert_includes member.errors[:email], "is invalid"
end

test "password must be at least 8 characters" do
  member = Member.new(email: "ana@example.com", password: "short", name: "Ana")
  refute member.valid?
  assert_includes member.errors[:password], "is too short (minimum is 8 characters)"
end

test "name is required" do
  member = Member.new(email: "ana@example.com", password: "secret123")
  refute member.valid?
  assert_includes member.errors[:name], "can't be blank"
end

test "kindle_email format is validated when present" do
  member = Member.new(
    email: "ana@example.com",
    password: "secret123",
    name: "Ana",
    kindle_email: "not-an-email"
  )
  refute member.valid?
  assert_includes member.errors[:kindle_email], "is invalid"
end

test "kindle_email may be blank" do
  member = Member.new(
    email: "ana@example.com",
    password: "secret123",
    name: "Ana",
    kindle_email: ""
  )
  assert member.valid?
end
```

- [ ] **Step 2: Run and verify failures**

Run:
```bash
bin/rails test test/models/member_test.rb
```

Expected: the new tests fail. The earlier "valid member can be created" still passes.

- [ ] **Step 3: Add validations to the model**

Replace `app/models/member.rb` with:

```ruby
class Member < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  has_secure_password

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :kindle_email, with: ->(e) { e.blank? ? nil : e.strip.downcase }

  validates :email,
    presence: true,
    uniqueness: true,
    format: { with: EMAIL_FORMAT }

  validates :name, presence: true

  validates :kindle_email,
    format: { with: EMAIL_FORMAT },
    allow_nil: true
end
```

- [ ] **Step 4: Run and verify pass**

Run:
```bash
bin/rails test test/models/member_test.rb
```

Expected: all 11 tests pass (4 original + 7 new).

- [ ] **Step 5: Commit**

```bash
git add app/models/member.rb test/models/member_test.rb
git commit -m "Add validations and normalization to Member"
```

---

## Task 7: `Session` model

**Files:**
- Create: `db/migrate/<ts>_create_sessions.rb`
- Create: `app/models/session.rb`
- Test: `test/models/session_test.rb`
- Modify: `app/models/member.rb`

- [ ] **Step 1: Generate the migration**

Run:
```bash
bin/rails generate model Session member:references token:string:uniq user_agent:string ip_address:string
```

Edit the generated migration `db/migrate/<timestamp>_create_sessions.rb` to ensure non-null token:

```ruby
class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.references :member, null: false, foreign_key: true
      t.string :token, null: false
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end

    add_index :sessions, :token, unique: true
  end
end
```

- [ ] **Step 2: Run the migration**

Run:
```bash
bin/rails db:migrate
```

Expected: success.

- [ ] **Step 3: Write the failing test**

Replace `test/models/session_test.rb`:

```ruby
require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "session belongs to a member" do
    member = members(:ana)
    session = Session.create!(member: member, token: SecureRandom.hex(32))
    assert_equal member, session.member
  end

  test "token is required" do
    session = Session.new(member: members(:ana))
    refute session.valid?
    assert_includes session.errors[:token], "can't be blank"
  end

  test "token must be unique" do
    Session.create!(member: members(:ana), token: "duplicate")
    other = Session.new(member: members(:admin), token: "duplicate")
    refute other.valid?
  end

  test "member has many sessions" do
    member = members(:ana)
    Session.create!(member: member, token: SecureRandom.hex(32))
    Session.create!(member: member, token: SecureRandom.hex(32))
    assert_equal 2, member.sessions.count
  end
end
```

Wipe `test/fixtures/sessions.yml` (or leave it empty):

```yaml
# empty — tests create sessions inline
```

- [ ] **Step 4: Run and verify failure**

Run:
```bash
bin/rails test test/models/session_test.rb
```

Expected: failures — no `has_many :sessions` on Member, no `validates :token` on Session.

- [ ] **Step 5: Implement Session model**

Replace `app/models/session.rb` with:

```ruby
class Session < ApplicationRecord
  belongs_to :member

  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  private

  def generate_token
    self.token ||= SecureRandom.hex(32)
  end
end
```

Update `app/models/member.rb` to add the association. Replace the file with:

```ruby
class Member < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :kindle_email, with: ->(e) { e.blank? ? nil : e.strip.downcase }

  validates :email,
    presence: true,
    uniqueness: true,
    format: { with: EMAIL_FORMAT }

  validates :name, presence: true

  validates :kindle_email,
    format: { with: EMAIL_FORMAT },
    allow_nil: true
end
```

- [ ] **Step 6: Run and verify pass**

Run:
```bash
bin/rails test test/models/session_test.rb test/models/member_test.rb
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add db/migrate db/schema.rb app/models test/models/session_test.rb test/fixtures/sessions.yml
git commit -m "Add Session model with member association"
```

---

## Task 8: `Authentication` concern

**Files:**
- Create: `app/controllers/concerns/authentication.rb`
- Modify: `app/controllers/application_controller.rb`
- Test: `test/integration/authentication_test.rb`

- [ ] **Step 1: Write the failing integration test**

Create `test/integration/authentication_test.rb`:

```ruby
require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "unauthenticated request to root is redirected to /sign_in" do
    get "/"
    assert_redirected_to "/sign_in"
  end

  test "authenticated request to root proceeds (does not redirect to /sign_in)" do
    sign_in_as members(:ana)
    get "/"
    assert_response :success
  end

  private

  def sign_in_as(member)
    session = member.sessions.create!(token: SecureRandom.hex(32))
    cookies.signed[:session_token] = { value: session.token, httponly: true }
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run:
```bash
bin/rails test test/integration/authentication_test.rb
```

Expected: failure — there is no `/sign_in` route yet, and root is the Rails welcome page (not protected).

- [ ] **Step 3: Create the Authentication concern**

Create `app/controllers/concerns/authentication.rb`:

```ruby
module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_member, :signed_in?
    before_action :require_login
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_login, **options
    end
  end

  private

  def current_member
    Current.member ||= load_member_from_session
  end

  def signed_in?
    current_member.present?
  end

  def require_login
    return if signed_in?
    redirect_to sign_in_path
  end

  def require_admin
    return if current_member&.admin?
    raise ActionController::RoutingError.new("Not Found")
  end

  def sign_in(member)
    session_record = member.sessions.create!(
      token: SecureRandom.hex(32),
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
    cookies.signed.permanent[:session_token] = { value: session_record.token, httponly: true }
    Current.member = member
  end

  def sign_out
    Session.find_by(token: cookies.signed[:session_token])&.destroy
    cookies.delete(:session_token)
    Current.member = nil
  end

  def load_member_from_session
    token = cookies.signed[:session_token]
    return nil unless token
    Session.find_by(token: token)&.member
  end
end
```

Create `app/models/current.rb` (Rails has `CurrentAttributes`):

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :member
end
```

Update `app/controllers/application_controller.rb`:

```ruby
class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
end
```

Add a placeholder root route and sign_in route to `config/routes.rb`. Replace `config/routes.rb` with:

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "sign_in", to: "sessions#new", as: :sign_in
  post "session", to: "sessions#create", as: :session
  delete "session", to: "sessions#destroy"

  root "books#index"
end
```

- [ ] **Step 4: Add stub controllers so routes resolve**

Create `app/controllers/sessions_controller.rb` (stub — real implementation in Task 9):

```ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
    head :ok
  end

  def create
    head :ok
  end

  def destroy
    head :ok
  end
end
```

Create `app/controllers/books_controller.rb` (stub — real implementation in Task 11):

```ruby
class BooksController < ApplicationController
  def index
    head :ok
  end
end
```

- [ ] **Step 5: Run and verify pass**

Run:
```bash
bin/rails test test/integration/authentication_test.rb
```

Expected: 2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers app/models/current.rb config/routes.rb test/integration/authentication_test.rb
git commit -m "Add Authentication concern with session cookie support"
```

---

## Task 9: `SessionsController` + login form

**Files:**
- Modify: `app/controllers/sessions_controller.rb`
- Create: `app/views/sessions/new.html.erb`
- Test: `test/controllers/sessions_controller_test.rb`

- [ ] **Step 1: Write the failing controller test**

Replace `test/controllers/sessions_controller_test.rb` with:

```ruby
require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /sign_in renders the form with Romanian labels" do
    get sign_in_path
    assert_response :success
    assert_select "h1", "Autentificare"
    assert_select "label", "Email"
    assert_select "label", "Parolă"
    assert_select "input[type=submit][value=?]", "Intră în cont"
  end

  test "POST /session with valid credentials signs the member in and redirects to root" do
    post session_path, params: { email: "ana@example.com", password: "secret123" }
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "POST /session with invalid credentials re-renders form with error" do
    post session_path, params: { email: "ana@example.com", password: "wrong" }
    assert_response :unprocessable_entity
    assert_select "p.flash-error", "Email sau parolă greșite."
  end

  test "POST /session with unknown email re-renders form" do
    post session_path, params: { email: "nobody@example.com", password: "anything" }
    assert_response :unprocessable_entity
  end

  test "DELETE /session signs the member out" do
    sign_in_as members(:ana)
    delete session_path
    assert_redirected_to sign_in_path
    assert_nil cookies[:session_token].presence
  end

  private

  def sign_in_as(member)
    session = member.sessions.create!(token: SecureRandom.hex(32))
    cookies.signed[:session_token] = { value: session.token, httponly: true }
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run:
```bash
bin/rails test test/controllers/sessions_controller_test.rb
```

Expected: all 5 tests fail — the stub controller returns `:ok` with no view.

- [ ] **Step 3: Implement `SessionsController`**

Replace `app/controllers/sessions_controller.rb`:

```ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
  end

  def create
    member = Member.find_by(email: params[:email].to_s.strip.downcase)
    if member&.authenticate(params[:password])
      sign_in(member)
      redirect_to root_path
    else
      flash.now[:error] = I18n.t("sessions.new.invalid")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out
    redirect_to sign_in_path
  end
end
```

- [ ] **Step 4: Create the login view**

Create `app/views/sessions/new.html.erb`:

```erb
<div class="mx-auto max-w-md py-12">
  <h1 class="text-3xl font-bold mb-6"><%= t("sessions.new.title") %></h1>

  <% if flash[:error] %>
    <p class="flash-error text-red-600 mb-4"><%= flash[:error] %></p>
  <% end %>

  <%= form_with url: session_path, method: :post, local: true, class: "space-y-4" do |f| %>
    <div>
      <%= f.label :email, t("sessions.new.email"), class: "block text-sm font-medium" %>
      <%= f.email_field :email, required: true, autofocus: true,
            class: "mt-1 block w-full rounded border-gray-300" %>
    </div>

    <div>
      <%= f.label :password, t("sessions.new.password"), class: "block text-sm font-medium" %>
      <%= f.password_field :password, required: true,
            class: "mt-1 block w-full rounded border-gray-300" %>
    </div>

    <%= f.submit t("sessions.new.submit"),
          class: "rounded bg-indigo-600 px-4 py-2 text-white" %>
  <% end %>
</div>
```

- [ ] **Step 5: Run and verify pass**

Run:
```bash
bin/rails test test/controllers/sessions_controller_test.rb
```

Expected: all 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/sessions_controller.rb app/views/sessions test/controllers/sessions_controller_test.rb
git commit -m "Implement sessions login/logout with Romanian form"
```

---

## Task 10: `BooksController#index` — empty catalog placeholder

**Files:**
- Modify: `app/controllers/books_controller.rb`
- Create: `app/views/books/index.html.erb`
- Test: `test/controllers/books_controller_test.rb`

This task comes before the layout task because the layout test (Task 11) visits `root_path`, which needs a real rendered view in order for the layout to be applied.

- [ ] **Step 1: Write the failing test**

Create `test/controllers/books_controller_test.rb`:

```ruby
require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  test "signed-in member sees the empty catalog placeholder" do
    sign_in_as members(:ana)
    get root_path
    assert_response :success
    assert_select "h1", "Bibliotecă"
    assert_select "p", "Niciun titlu disponibil"
  end

  test "unauthenticated visitor is redirected to /sign_in" do
    get root_path
    assert_redirected_to sign_in_path
  end

  private

  def sign_in_as(member)
    session = member.sessions.create!(token: SecureRandom.hex(32))
    cookies.signed[:session_token] = { value: session.token, httponly: true }
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run:
```bash
bin/rails test test/controllers/books_controller_test.rb
```

Expected: failure — stub controller returns `:ok` with no view, so `assert_select` finds nothing.

- [ ] **Step 3: Implement controller and view**

Replace `app/controllers/books_controller.rb`:

```ruby
class BooksController < ApplicationController
  def index
  end
end
```

Create `app/views/books/index.html.erb`:

```erb
<h1 class="text-3xl font-bold mb-6"><%= t("books.index.title") %></h1>

<p class="text-gray-600 italic"><%= t("books.index.empty") %></p>
```

- [ ] **Step 4: Run and verify pass**

Run:
```bash
bin/rails test test/controllers/books_controller_test.rb
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/books_controller.rb app/views/books test/controllers/books_controller_test.rb
git commit -m "Add empty-state catalog page"
```

---

## Task 11: Application layout in Romanian

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `config/routes.rb`
- Create: `app/controllers/admin/members_controller.rb` (stub — real impl in Task 13)
- Test: `test/integration/layout_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/integration/layout_test.rb`:

```ruby
require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  test "layout shows app name and Romanian nav when signed in" do
    sign_in_as members(:ana)
    get root_path
    assert_response :success
    assert_select "header" do
      assert_select "a", "Familioteca"
      assert_select "a", "Bibliotecă"
    end
  end

  test "layout omits admin link for non-admins" do
    sign_in_as members(:ana)
    get root_path
    assert_select "a", { text: "Administrare", count: 0 }
  end

  test "layout shows admin link for admins" do
    sign_in_as members(:admin)
    get root_path
    assert_select "a", "Administrare"
  end

  test "layout shows sign-out button when signed in" do
    sign_in_as members(:ana)
    get root_path
    assert_select "button", "Deconectare"
  end

  private

  def sign_in_as(member)
    session = member.sessions.create!(token: SecureRandom.hex(32))
    cookies.signed[:session_token] = { value: session.token, httponly: true }
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run:
```bash
bin/rails test test/integration/layout_test.rb
```

Expected: failures — the default layout doesn't have a header with these elements; also `admin_members_path` isn't defined yet so the test errors when trying to resolve the helper inside the layout.

- [ ] **Step 3: Add the admin namespace route and a stub controller**

The layout will reference `admin_members_path`, so the route must exist. Update `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "sign_in", to: "sessions#new", as: :sign_in
  post "session", to: "sessions#create", as: :session
  delete "session", to: "sessions#destroy"

  namespace :admin do
    resources :members, only: [:index]
  end

  root "books#index"
end
```

Create a stub `app/controllers/admin/members_controller.rb` (replaced with the real implementation in Task 13):

```ruby
module Admin
  class MembersController < ApplicationController
    def index
      head :ok
    end
  end
end
```

- [ ] **Step 4: Update the layout**

Replace `app/views/layouts/application.html.erb`:

```erb
<!DOCTYPE html>
<html lang="ro">
  <head>
    <title><%= t("app.name") %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="min-h-screen bg-gray-50 text-gray-900">
    <% if signed_in? %>
      <header class="bg-white border-b">
        <nav class="mx-auto max-w-5xl px-4 py-3 flex items-center justify-between">
          <%= link_to t("app.name"), root_path, class: "font-bold text-lg" %>
          <div class="flex items-center gap-4 text-sm">
            <%= link_to t("navigation.catalog"), root_path %>
            <% if current_member.admin? %>
              <%= link_to t("navigation.admin"), admin_members_path %>
            <% end %>
            <span class="text-gray-500"><%= current_member.name %></span>
            <%= button_to t("sessions.destroy.link"), session_path, method: :delete,
                  class: "text-sm underline" %>
          </div>
        </nav>
      </header>
    <% end %>

    <main class="mx-auto max-w-5xl px-4 py-6">
      <%= yield %>
    </main>
  </body>
</html>
```

- [ ] **Step 5: Run and verify pass**

Run:
```bash
bin/rails test test/integration/layout_test.rb
```

Expected: 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/layouts/application.html.erb app/controllers/admin config/routes.rb test/integration/layout_test.rb
git commit -m "Add Romanian application layout with conditional admin nav"
```

---

## Task 12: `Admin::BaseController` — 404 for non-admins

**Files:**
- Create: `app/controllers/admin/base_controller.rb`
- Modify: `app/controllers/admin/members_controller.rb`
- Test: `test/controllers/admin/access_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/admin/access_test.rb`:

```ruby
require "test_helper"

class Admin::AccessTest < ActionDispatch::IntegrationTest
  test "non-admin gets 404 on /admin/members" do
    sign_in_as members(:ana)
    assert_raises(ActionController::RoutingError) do
      get admin_members_path
    end
  end

  test "unauthenticated user is redirected to /sign_in for /admin/members" do
    get admin_members_path
    assert_redirected_to sign_in_path
  end

  test "admin reaches /admin/members successfully" do
    sign_in_as members(:admin)
    get admin_members_path
    assert_response :success
  end

  private

  def sign_in_as(member)
    session = member.sessions.create!(token: SecureRandom.hex(32))
    cookies.signed[:session_token] = { value: session.token, httponly: true }
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run:
```bash
bin/rails test test/controllers/admin/access_test.rb
```

Expected: failures — the stub `Admin::MembersController` returns `:ok` for everyone.

- [ ] **Step 3: Create `Admin::BaseController` and update `MembersController`**

Create `app/controllers/admin/base_controller.rb`:

```ruby
module Admin
  class BaseController < ApplicationController
    before_action :require_admin
  end
end
```

Replace `app/controllers/admin/members_controller.rb`:

```ruby
module Admin
  class MembersController < BaseController
    def index
      head :ok
    end
  end
end
```

(Real `index` body comes in Task 13.)

- [ ] **Step 4: Run and verify pass**

Run:
```bash
bin/rails test test/controllers/admin/access_test.rb
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin test/controllers/admin
git commit -m "Add Admin::BaseController with 404 for non-admins"
```

---

## Task 13: `Admin::MembersController#index`

**Files:**
- Modify: `app/controllers/admin/members_controller.rb`
- Create: `app/views/admin/members/index.html.erb`
- Test: `test/controllers/admin/members_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/admin/members_controller_test.rb`:

```ruby
require "test_helper"

class Admin::MembersControllerTest < ActionDispatch::IntegrationTest
  test "lists all members in a table" do
    sign_in_as members(:admin)
    get admin_members_path
    assert_response :success
    assert_select "h1", "Membri"
    assert_select "table tbody tr", 2
    assert_select "td", text: "Ana"
    assert_select "td", text: "Administrator"
    assert_select "td", text: "ana@example.com"
    assert_select "td", text: "admin@example.com"
  end

  private

  def sign_in_as(member)
    session = member.sessions.create!(token: SecureRandom.hex(32))
    cookies.signed[:session_token] = { value: session.token, httponly: true }
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run:
```bash
bin/rails test test/controllers/admin/members_controller_test.rb
```

Expected: failure — stub returns `:ok`, no view rendered.

- [ ] **Step 3: Implement controller and view**

Replace `app/controllers/admin/members_controller.rb`:

```ruby
module Admin
  class MembersController < BaseController
    def index
      @members = Member.order(:name)
    end
  end
end
```

Create `app/views/admin/members/index.html.erb`:

```erb
<h1 class="text-3xl font-bold mb-6"><%= t("admin.members.index.title") %></h1>

<table class="min-w-full divide-y divide-gray-200">
  <thead class="bg-gray-50">
    <tr>
      <th class="px-4 py-2 text-left"><%= t("admin.members.index.name") %></th>
      <th class="px-4 py-2 text-left"><%= t("admin.members.index.email") %></th>
      <th class="px-4 py-2 text-left"><%= t("admin.members.index.kindle_email") %></th>
      <th class="px-4 py-2 text-left"><%= t("admin.members.index.role") %></th>
    </tr>
  </thead>
  <tbody class="bg-white divide-y divide-gray-200">
    <% @members.each do |member| %>
      <tr>
        <td class="px-4 py-2"><%= member.name %></td>
        <td class="px-4 py-2"><%= member.email %></td>
        <td class="px-4 py-2"><%= member.kindle_email || "—" %></td>
        <td class="px-4 py-2">
          <%= member.admin? ? t("admin.members.index.admin") : t("admin.members.index.member") %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

- [ ] **Step 4: Run and verify pass**

Run:
```bash
bin/rails test test/controllers/admin/members_controller_test.rb
```

Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/members_controller.rb app/views/admin/members test/controllers/admin/members_controller_test.rb
git commit -m "Add admin members index"
```

---

## Task 14: Seeds — first admin member

**Files:**
- Modify: `db/seeds.rb`
- Test: `test/integration/seeds_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/integration/seeds_test.rb`:

```ruby
require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds creates one admin member when run on an empty database" do
    Member.delete_all
    load Rails.root.join("db/seeds.rb")
    admin = Member.find_by!(admin: true)
    assert_equal 1, Member.where(admin: true).count
    assert admin.authenticate("changeme123")
  end

  test "seeds is idempotent" do
    Member.delete_all
    load Rails.root.join("db/seeds.rb")
    load Rails.root.join("db/seeds.rb")
    assert_equal 1, Member.where(admin: true).count
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run:
```bash
bin/rails test test/integration/seeds_test.rb
```

Expected: failure — `db/seeds.rb` is empty.

- [ ] **Step 3: Implement seeds**

Replace `db/seeds.rb`:

```ruby
admin_email = ENV.fetch("FAMILIOTECA_ADMIN_EMAIL", "admin@familioteca.local")
admin_password = ENV.fetch("FAMILIOTECA_ADMIN_PASSWORD", "changeme123")
admin_name = ENV.fetch("FAMILIOTECA_ADMIN_NAME", "Administrator")

Member.find_or_create_by!(email: admin_email) do |m|
  m.password = admin_password
  m.name = admin_name
  m.admin = true
end
```

- [ ] **Step 4: Run and verify pass**

Run:
```bash
bin/rails test test/integration/seeds_test.rb
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add db/seeds.rb test/integration/seeds_test.rb
git commit -m "Add seeds for initial admin member"
```

---

## Task 15: Rack::Attack login rate limiting

**Files:**
- Create: `config/initializers/rack_attack.rb`
- Modify: `config/application.rb`
- Test: `test/integration/rack_attack_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/integration/rack_attack_test.rb`:

```ruby
require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
  end

  teardown do
    Rack::Attack.enabled = false
  end

  test "11th failed login from the same IP is throttled" do
    10.times do |i|
      post session_path, params: { email: "ana@example.com", password: "wrong#{i}" },
        env: { "REMOTE_ADDR" => "203.0.113.42" }
      assert_response :unprocessable_entity, "attempt #{i + 1} should not be throttled"
    end

    post session_path, params: { email: "ana@example.com", password: "wrong_final" },
      env: { "REMOTE_ADDR" => "203.0.113.42" }
    assert_response :too_many_requests
  end

  test "different IPs are tracked independently" do
    10.times do
      post session_path, params: { email: "ana@example.com", password: "wrong" },
        env: { "REMOTE_ADDR" => "203.0.113.42" }
    end

    post session_path, params: { email: "ana@example.com", password: "wrong" },
      env: { "REMOTE_ADDR" => "203.0.113.99" }
    assert_response :unprocessable_entity
  end
end
```

- [ ] **Step 2: Run and verify failure**

Run:
```bash
bin/rails test test/integration/rack_attack_test.rb
```

Expected: failures — Rack::Attack isn't configured.

- [ ] **Step 3: Configure Rack::Attack**

Create `config/initializers/rack_attack.rb`:

```ruby
class Rack::Attack
  self.enabled = !Rails.env.test? || ENV["RACK_ATTACK"] == "1"

  throttle("logins/ip", limit: 10, period: 10.minutes) do |req|
    if req.path == "/session" && req.post?
      req.ip
    end
  end

  self.throttled_responder = lambda do |request|
    [429, { "Content-Type" => "text/plain" }, ["Prea multe încercări. Așteaptă 10 minute."]]
  end
end
```

Update `config/application.rb` — inside `class Application < Rails::Application`, add:

```ruby
config.middleware.use Rack::Attack
```

The test enables `Rack::Attack` manually via `Rack::Attack.enabled = true` in `setup` since the initializer disables it in test mode by default.

- [ ] **Step 4: Run and verify pass**

Run:
```bash
bin/rails test test/integration/rack_attack_test.rb
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add config/initializers/rack_attack.rb config/application.rb test/integration/rack_attack_test.rb
git commit -m "Rate-limit failed logins via Rack::Attack"
```

---

## Done. What this phase produced

- Rails 8 app skeleton at `~/code/ghcom/adimoldovan/familioteca` with SQLite, Tailwind, Solid Queue/Cache/Cable.
- Romanian locale + Bucharest timezone wired at the framework level.
- `DiacriticFolding.fold` ready for use by the catalog (Phase 2).
- `Member` and `Session` models with hand-rolled `has_secure_password` + cookie-based session storage.
- `Authentication` concern providing `current_member`, `signed_in?`, `require_login`, `require_admin`, `sign_in`, `sign_out`.
- Sessions UI (login form + logout button) entirely in Romanian.
- Admin-only members index at `/admin/members`. Non-admins get 404 on `/admin/*`.
- Empty catalog placeholder at `/`.
- Seeds for the first admin account.
- Login rate-limiting via Rack::Attack (10 failures / 10 min / IP).
- All covered by Minitest with 11 test files, no system tests (those live in the Playwright project, coming in Phase 5).

---

## Next phase: Phase 2 — Catalog & Ingestion

When you're ready, the next plan will cover: `BookStorage` service over S3/R2, `Ebook::Parser` (EPUB + MOBI), `Book` model and its `sort_title` / `searchable` columns, `Active Storage` for covers, `IngestBookJob` + `ProcessBookFileJob`, "Scan library now" admin action, and the catalog browse/search UI.
