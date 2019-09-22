# Sends e-mails.
class DssMailer < ActionMailer::Base
  default from: 'Letters and Science IT Service Center <lshelp@ucdavis.edu>'

  def deliver_message(subject, message, message_receipt_id, member, footer)
    @message = message
    @footer = footer
    @mle_id = message_receipt_id

    Rails.logger.info "Sending e-mail with subject '#{subject}' to e-mail address '#{member.email}' ('#{member.name}') ..."

    begin
      mail(to: "#{member.name} <#{member.email}>", subject: subject).deliver!
      Rails.logger.info "Success sending e-mail '#{member.email}'"
    rescue Net::SMTPFatalError => e
      if e.backtrace.include?('User unknown')
        # Nothing we can do about an incorrect e-mail address ...
        Rails.logger.warn("SMTP returned 'User unknown' for #{member.name} <#{member.email}>")
      elsif e.backtrace.include?('expired account')
        # Nothing we can do about an expired account ...
        Rails.logger.warn("SMTP returned 'expired account' for #{member.name} <#{member.email}>")
      else
        # Not going to handle it after all ...
        Rails.logger.warn("Unhandled exception when sending e-mail to #{member.email}")
        Rails.logger.warn("Exception:")
        Rails.logger.warn(e.backtrace)
        raise(e)
      end
    end
  end
end
