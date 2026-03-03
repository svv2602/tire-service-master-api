# frozen_string_literal: true

# AuditLogCleanupJob -- automatically rotates (deletes) old audit log entries.
# By default removes system_logs older than 90 days.
# Intended to be run periodically via cron / whenever.
class AuditLogCleanupJob < ApplicationJob
  queue_as :schedules

  # @param older_than [ActiveSupport::Duration, Time] cutoff; records created before this are deleted
  def perform(older_than: 90.days.ago)
    cutoff = older_than.is_a?(ActiveSupport::Duration) ? older_than : older_than
    count = SystemLog.where('created_at < ?', cutoff).delete_all

    Rails.logger.info "[AuditLogCleanupJob] Deleted #{count} audit log entries older than #{cutoff}"
  end
end
