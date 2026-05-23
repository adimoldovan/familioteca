class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("FAMILIOTECA_FROM_EMAIL") {
    raise "Set FAMILIOTECA_FROM_EMAIL – see docs/operations.md" unless Rails.env.local? || Rails.env.e2e?
    "familioteca-test@example.com"
  }
  layout "mailer"
end
