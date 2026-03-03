# frozen_string_literal: true

# CurrentContext provides a thread-safe, request-scoped store for audit
# and request metadata.  It replaces the old Thread.current[:...] pattern
# which is not safe when using Puma in clustered mode with thread re-use.
#
# ActiveSupport::CurrentAttributes is automatically reset at the end of
# every request (via a middleware / executor callback), so there is no
# risk of leaking state between requests.
#
# Usage:
#   CurrentContext.ip_address = request.remote_ip
#   CurrentContext.ip_address  # => "127.0.0.1"
class CurrentContext < ActiveSupport::CurrentAttributes
  attribute :ip_address,
            :user_agent,
            :request_id,
            :session_id,
            :audit_user,
            :skip_audit,
            :force_async_audit,
            :request_start_time,
            :request_context
end
