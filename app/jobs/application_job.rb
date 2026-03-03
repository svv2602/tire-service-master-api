class ApplicationJob < ActiveJob::Base
  # Retry on database deadlocks with a short wait
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Discard jobs when the underlying record no longer exists
  discard_on ActiveJob::DeserializationError

  # Generic retry with polynomial backoff for transient errors
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
end
