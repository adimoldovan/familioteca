# E2E env. Mirrors test.rb but boots a real HTTP server for Playwright.
# RAILS_ENV=e2e is set by bin/e2e-server. Don't use this env for anything
# other than Playwright runs.

require_relative "test"

Rails.application.configure do
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :rescuable

  # Rails treats any non-test custom env as production-like and requires a
  # secret_key_base. CI has no master key to decrypt credentials, so set a
  # hardcoded dummy — this env only serves Playwright runs.
  config.secret_key_base = "e2e_secret_key_base_not_a_real_secret"

  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "localhost" }

  # Propshaft only mounts its asset server for development and test by default.
  # Playwright drives a real browser, so JS/CSS must be served — enable it here.
  config.assets.server = true

  # AWS SDK is stubbed in this env too — the seed_book endpoint creates Books
  # directly so no real bucket call is needed.
  config.after_initialize do
    require "aws-sdk-s3"
    Aws.config[:stub_responses] = true
  end
end
