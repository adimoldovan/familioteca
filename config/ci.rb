# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"
  step "Style: Ruby", "bin/rubocop"
  # step "Style: ESLint", "npm run lint"
  # step "Type-check: TypeScript", "npm run typecheck"
  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  # step "Docs: OpenAPI spec up to date and valid", "bin/rails openapi:check"
  step "Tests: Rails", "bin/rails test"
  # step "Tests: JavaScript", "npm run test:js"
  # step "Tests: End-to-End", "npm run test:e2e"
end
