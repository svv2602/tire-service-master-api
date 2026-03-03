# frozen_string_literal: true

# Remove duplicate indexes on system_logs table to reduce storage and
# write overhead.  Each removed index is covered by an identical or
# broader remaining index.
#
# Duplicate GIN indexes on additional_data (keep idx_system_logs_additional_data_gin):
#   - index_system_logs_on_additional_data (duplicate)
#
# Duplicate GIN indexes on record_changes (keep idx_system_logs_changes_gin):
#   - idx_system_logs_record_changes_gin (duplicate)
#   - index_system_logs_on_record_changes (duplicate)
#
# Duplicate composite index on [user_id, created_at] (keep idx_system_logs_user_created):
#   - index_system_logs_on_user_id_and_created_at (duplicate)
class RemoveDuplicateSystemLogsIndexes < ActiveRecord::Migration[8.0]
  def up
    # Duplicate GIN index on additional_data
    remove_index :system_logs, name: :index_system_logs_on_additional_data, if_exists: true

    # Duplicate GIN indexes on record_changes (keep idx_system_logs_changes_gin)
    remove_index :system_logs, name: :idx_system_logs_record_changes_gin, if_exists: true
    remove_index :system_logs, name: :index_system_logs_on_record_changes, if_exists: true

    # Duplicate composite index on [user_id, created_at]
    remove_index :system_logs, name: :index_system_logs_on_user_id_and_created_at, if_exists: true
  end

  def down
    # Re-create removed indexes for rollback
    add_index :system_logs, :additional_data,
              name: :index_system_logs_on_additional_data,
              using: :gin

    add_index :system_logs, :record_changes,
              name: :idx_system_logs_record_changes_gin,
              using: :gin

    add_index :system_logs, :record_changes,
              name: :index_system_logs_on_record_changes,
              using: :gin

    add_index :system_logs, [:user_id, :created_at],
              name: :index_system_logs_on_user_id_and_created_at
  end
end
