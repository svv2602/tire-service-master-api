# frozen_string_literal: true

# AdminNotificationService - sends notifications to administrators
# about critical events in the system.
#
# Integrates with email (SecurityMailer) and Telegram to ensure
# admins are informed about:
# - User suspensions
# - Suspicious activity
# - Critical resource deletions
#
# All public methods are safe to call -- they rescue errors internally
# to avoid breaking the calling code (e.g. AuditLogJob).
class AdminNotificationService
  class << self
    # Notify admins when a user is suspended.
    #
    # @param suspended_by [User, nil] admin who performed the suspension
    # @param target_user_id [Integer] ID of the suspended user
    # @param reason [String, nil] reason for suspension
    # @param until_date [String, Date, nil] suspension end date
    def notify_user_suspended(suspended_by:, target_user_id:, reason:, until_date: nil)
      target_user = User.find_by(id: target_user_id)

      message = build_suspension_message(
        suspended_by: suspended_by,
        target_user: target_user,
        target_user_id: target_user_id,
        reason: reason,
        until_date: until_date
      )

      deliver_to_all_channels(
        subject: "User suspended: ##{target_user_id}",
        message: message
      )
    rescue StandardError => e
      log_error('notify_user_suspended', e)
    end

    # Notify admins about suspicious activity.
    #
    # @param user [User] the user exhibiting suspicious behavior
    # @param activity_type [String] type of suspicious activity
    # @param count [Integer] number of occurrences
    # @param ip_address [String, nil] last known IP address
    def notify_suspicious_activity(user:, activity_type:, count:, ip_address: nil)
      message = build_suspicious_activity_message(
        user: user,
        activity_type: activity_type,
        count: count,
        ip_address: ip_address
      )

      deliver_to_all_channels(
        subject: "Suspicious activity: #{activity_type}",
        message: message
      )
    rescue StandardError => e
      log_error('notify_suspicious_activity', e)
    end

    # Notify admins when a critical resource is deleted.
    #
    # @param deleted_by [User, nil] admin who performed the deletion
    # @param resource_type [String] model class name (e.g. "User", "ServicePoint")
    # @param resource_id [Integer] ID of the deleted resource
    def notify_critical_deletion(deleted_by:, resource_type:, resource_id:)
      message = build_critical_deletion_message(
        deleted_by: deleted_by,
        resource_type: resource_type,
        resource_id: resource_id
      )

      deliver_to_all_channels(
        subject: "Critical deletion: #{resource_type} ##{resource_id}",
        message: message
      )
    rescue StandardError => e
      log_error('notify_critical_deletion', e)
    end

    # Notify admins when an audit log operation fails.
    #
    # @param error [StandardError] the error that occurred
    def notify_audit_failure(error)
      message = build_audit_failure_message(error)

      deliver_to_all_channels(
        subject: "Audit log failure: #{error.class.name}",
        message: message
      )
    rescue StandardError => e
      log_error('notify_audit_failure', e)
    end

    # Notify admins when a Sidekiq job permanently fails.
    #
    # @param job_class [String] class name of the failed job
    # @param error_message [String] error message from the last attempt
    # @param job_id [String] Sidekiq job ID
    def notify_job_permanently_failed(job_class:, error_message:, job_id: nil)
      message = build_job_failure_message(
        job_class: job_class,
        error_message: error_message,
        job_id: job_id
      )

      deliver_to_all_channels(
        subject: "Sidekiq job permanently failed: #{job_class}",
        message: message
      )
    rescue StandardError => e
      log_error('notify_job_permanently_failed', e)
    end

    private

    # -------------------------------------------------------------------
    # Message builders
    # -------------------------------------------------------------------

    def build_suspension_message(suspended_by:, target_user:, target_user_id:, reason:, until_date:)
      admin_label = suspended_by ? "#{suspended_by.email} (ID: #{suspended_by.id})" : 'System'
      target_label = target_user ? "#{target_user.email} (ID: #{target_user.id})" : "User ##{target_user_id}"
      duration = until_date.present? ? "until #{until_date}" : 'permanent'

      <<~MSG.strip
        *User Suspended*

        Suspended by: #{admin_label}
        Target user: #{target_label}
        Reason: #{reason || 'not specified'}
        Duration: #{duration}
        Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}
      MSG
    end

    def build_suspicious_activity_message(user:, activity_type:, count:, ip_address:)
      <<~MSG.strip
        *Suspicious Activity Detected*

        User: #{user.email} (ID: #{user.id})
        Activity: #{activity_type}
        Count: #{count}
        IP: #{ip_address || 'unknown'}
        Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}
      MSG
    end

    def build_critical_deletion_message(deleted_by:, resource_type:, resource_id:)
      admin_label = deleted_by ? "#{deleted_by.email} (ID: #{deleted_by.id})" : 'System'

      <<~MSG.strip
        *Critical Resource Deleted*

        Deleted by: #{admin_label}
        Resource: #{resource_type} ##{resource_id}
        Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}
      MSG
    end

    def build_audit_failure_message(error)
      <<~MSG.strip
        *Audit Log Failure*

        Error: #{error.class.name}
        Message: #{error.message}
        Backtrace: #{error.backtrace&.first(3)&.join("\n")}
        Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}
      MSG
    end

    def build_job_failure_message(job_class:, error_message:, job_id:)
      <<~MSG.strip
        *Sidekiq Job Permanently Failed*

        Job: #{job_class}
        Job ID: #{job_id || 'unknown'}
        Error: #{error_message}
        Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}
      MSG
    end

    # -------------------------------------------------------------------
    # Delivery
    # -------------------------------------------------------------------

    # Send notification through all configured channels.
    def deliver_to_all_channels(subject:, message:)
      send_telegram_notification(message)
      send_email_notification(subject: subject, message: message)
    end

    # Send a Telegram message to the admin chat.
    def send_telegram_notification(message)
      return unless ENV['TELEGRAM_BOT_TOKEN'].present? && ENV['TELEGRAM_ADMIN_CHAT_ID'].present?

      TelegramService.new.send_message(
        ENV['TELEGRAM_ADMIN_CHAT_ID'],
        message,
        nil,
        'Markdown'
      )
    rescue StandardError => e
      Rails.logger.error "[AdminNotificationService] Telegram delivery failed: #{e.message}"
    end

    # Send an email to all admin users.
    def send_email_notification(subject:, message:)
      admin_emails = User.where(role: 'admin').pluck(:email).compact
      return if admin_emails.empty?

      admin_emails.each do |email|
        AdminNotificationMailer.admin_alert(
          email: email,
          subject: subject,
          body: message
        ).deliver_later
      rescue StandardError => e
        Rails.logger.error "[AdminNotificationService] Email delivery to #{email} failed: #{e.message}"
      end
    rescue StandardError => e
      Rails.logger.error "[AdminNotificationService] Email delivery failed: #{e.message}"
    end

    # -------------------------------------------------------------------
    # Logging
    # -------------------------------------------------------------------

    def log_error(method, error)
      Rails.logger.error "[AdminNotificationService] #{method} failed: #{error.message}"
      Rails.logger.error error.backtrace&.first(5)&.join("\n")
    end
  end
end
