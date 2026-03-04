# frozen_string_literal: true

# Phase-03: Elasticsearch configuration for tire catalog full-text search.
# When ELASTICSEARCH_URL is not set, all ES features gracefully fall back to
# PostgreSQL full-text search (tsvector + ILIKE).

if defined?(Elasticsearch::Model)
  elasticsearch_url = ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9200')

  Elasticsearch::Model.client = Elasticsearch::Client.new(
    url: elasticsearch_url,
    log: Rails.env.development?,
    transport_options: {
      request: { timeout: 5 }
    }
  )

  Rails.logger.info "[Elasticsearch] Configured with URL: #{elasticsearch_url}"
end
