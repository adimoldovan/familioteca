# E2E env. Mirrors test.rb but boots a real HTTP server for Playwright.
# RAILS_ENV=e2e is set by bin/e2e-server. Don't use this env for anything
# other than Playwright runs.

require_relative "test"

Rails.application.configure do
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :rescuable

  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "localhost" }

  # AWS SDK is stubbed in this env too — the seed_book endpoint creates Books
  # directly so no real bucket call is needed.
  config.after_initialize do
    require "aws-sdk-s3"
    Aws.config[:stub_responses] = true
  end
end
