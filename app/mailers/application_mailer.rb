class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "ExpertHub <noreply@experthub.app>")
  layout "mailer"
end
