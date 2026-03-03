class AddIndexesToNotificationLogs < ActiveRecord::Migration[8.0]
  def change
    # Single-column indexes for filtering and grouping
    add_index :notification_logs, :notification_type
    add_index :notification_logs, :status
    add_index :notification_logs, :template_type
    add_index :notification_logs, :template_id
    add_index :notification_logs, :recipient_email
    add_index :notification_logs, :sent_at
    add_index :notification_logs, :created_at

    # Polymorphic association index for recipient lookup
    add_index :notification_logs, [:recipient_type, :recipient_id]

    # Composite index: status + sent_at (time-range stats filtered by status)
    add_index :notification_logs, [:status, :sent_at], name: "idx_notification_logs_status_sent_at"

    # Composite index: status + created_at (failures ordered by created_at desc)
    add_index :notification_logs, [:status, :created_at], name: "idx_notification_logs_status_created_at"

    # Composite index: notification_type + status (stats grouped by type and status)
    add_index :notification_logs, [:notification_type, :status], name: "idx_notification_logs_type_status"

    # Composite index: template_type + status (template stats grouping)
    add_index :notification_logs, [:template_type, :status], name: "idx_notification_logs_template_type_status"
  end
end
