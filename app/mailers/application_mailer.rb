class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("FAMILIOTECA_FROM_EMAIL", "familioteca@example.com")
  layout "mailer"
end
