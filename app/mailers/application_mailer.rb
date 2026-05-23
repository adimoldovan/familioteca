class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("FAMILIOTECA_FROM_EMAIL") { raise "Set FAMILIOTECA_FROM_EMAIL – see docs/operations.md" }
  layout "mailer"
end
