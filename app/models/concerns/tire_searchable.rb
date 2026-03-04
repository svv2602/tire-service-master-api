# frozen_string_literal: true

# Phase-03: Elasticsearch integration for SupplierTireProduct.
# Provides full-text search with faceted filtering and graceful DB fallback.
#
# Usage:
#   SupplierTireProduct.es_search("Michelin 205/55 R16", filters: { season: "winter" })
#   SupplierTireProduct.es_facets("Michelin")
#
# When Elasticsearch is unavailable, all methods fall back to PostgreSQL
# full-text search (tsvector) so the application remains functional.
module TireSearchable
  extend ActiveSupport::Concern

  included do
    # Only load Elasticsearch integration if the gem is available
    if defined?(Elasticsearch::Model)
      include Elasticsearch::Model
      # Do NOT include Elasticsearch::Model::Callbacks — we manage reindex manually
      # to avoid slowing down bulk imports. Use `SupplierTireProduct.reindex_all!` instead.

      # Elasticsearch index settings
      settings index: {
        number_of_shards: 1,
        number_of_replicas: 0,
        analysis: {
          analyzer: {
            tire_analyzer: {
              type: 'custom',
              tokenizer: 'standard',
              filter: %w[lowercase asciifolding tire_synonym]
            }
          },
          filter: {
            tire_synonym: {
              type: 'synonym',
              synonyms: [
                'зимові,зимние,winter',
                'літні,летние,summer',
                'всесезонні,всесезонные,all_season',
                'r,R,радіус,радиус'
              ]
            }
          }
        }
      } do
        mappings dynamic: false do
          indexes :name,            type: 'text', analyzer: 'tire_analyzer', fields: { keyword: { type: 'keyword' } }
          indexes :original_brand,  type: 'text', analyzer: 'tire_analyzer', fields: { keyword: { type: 'keyword' } }
          indexes :brand_normalized, type: 'keyword'
          indexes :original_model,  type: 'text', analyzer: 'tire_analyzer', fields: { keyword: { type: 'keyword' } }
          indexes :description,     type: 'text', analyzer: 'tire_analyzer'

          # Structured fields for filtering
          indexes :width,           type: 'integer'
          indexes :height,          type: 'integer'
          indexes :diameter,        type: 'keyword'
          indexes :season,          type: 'keyword'
          indexes :price_uah,       type: 'float'
          indexes :in_stock,        type: 'boolean'
          indexes :supplier_id,     type: 'long'
          indexes :tire_brand_id,   type: 'long'
          indexes :tire_model_id,   type: 'long'
          indexes :country_id,      type: 'long'
          indexes :optimality_score, type: 'float'
          indexes :production_year, type: 'integer'
          indexes :load_index,      type: 'keyword'
          indexes :speed_index,     type: 'keyword'
          indexes :updated_at,      type: 'date'
        end
      end
    end
  end

  class_methods do
    # Full-text search with filters, falling back to DB when ES is unavailable.
    #
    # @param query [String] free-text search query
    # @param filters [Hash] optional filters (season, brand_id, width, height, diameter, in_stock, price_min, price_max)
    # @param page [Integer] page number (1-based)
    # @param per_page [Integer] results per page
    # @return [Hash] { results: [...], total: Integer, facets: {...} }
    def es_search(query, filters: {}, page: 1, per_page: 20)
      return db_fallback_search(query, filters, page, per_page) unless es_available?

      body = build_es_query(query, filters)
      body[:from] = (page.to_i - 1) * per_page.to_i
      body[:size] = per_page.to_i
      body[:sort] = [{ _score: :desc }, { optimality_score: { order: :desc, missing: '_last' } }]

      # Add aggregations for faceted search
      body[:aggs] = es_aggregations

      response = __elasticsearch__.search(body)

      {
        results: response.records.to_a,
        total: response.results.total.is_a?(Hash) ? response.results.total['value'] : response.results.total,
        facets: parse_aggregations(response.response['aggregations'])
      }
    rescue Elasticsearch::Transport::Transport::Error, Faraday::ConnectionFailed => e
      Rails.logger.warn "[TireSearchable] Elasticsearch query failed, falling back to DB: #{e.message}"
      db_fallback_search(query, filters, page, per_page)
    end

    # Get facets/aggregations for a given query (useful for filter sidebars).
    def es_facets(query = nil, filters: {})
      return db_fallback_facets(filters) unless es_available?

      body = build_es_query(query, filters)
      body[:size] = 0 # Only aggregations, no results
      body[:aggs] = es_aggregations

      response = __elasticsearch__.search(body)
      parse_aggregations(response.response['aggregations'])
    rescue StandardError => e
      Rails.logger.warn "[TireSearchable] ES facets failed: #{e.message}"
      db_fallback_facets(filters)
    end

    # Bulk reindex all products (run from console or background job).
    def reindex_all!
      return unless es_available?

      __elasticsearch__.create_index!(force: true)
      __elasticsearch__.import(batch_size: 500, scope: :in_stock)
      Rails.logger.info "[TireSearchable] Reindex complete: #{in_stock.count} products indexed"
    rescue StandardError => e
      Rails.logger.error "[TireSearchable] Reindex failed: #{e.message}"
    end

    # Check if Elasticsearch is available and configured.
    def es_available?
      return false unless defined?(Elasticsearch::Model) && ENV['ELASTICSEARCH_URL'].present?

      Elasticsearch::Model.client.ping
    rescue StandardError
      false
    end

    private

    def build_es_query(query, filters)
      must_clauses = []
      filter_clauses = []

      # Full-text query
      if query.present?
        must_clauses << {
          multi_match: {
            query: query,
            fields: %w[name^3 original_brand^2 original_model^2 brand_normalized^2 description],
            type: 'best_fields',
            fuzziness: 'AUTO'
          }
        }
      end

      # Structured filters
      filter_clauses << { term: { season: filters[:season] } } if filters[:season].present?
      filter_clauses << { term: { tire_brand_id: filters[:brand_id] } } if filters[:brand_id].present?
      filter_clauses << { term: { width: filters[:width].to_i } } if filters[:width].present?
      filter_clauses << { term: { height: filters[:height].to_i } } if filters[:height].present?
      filter_clauses << { term: { diameter: filters[:diameter] } } if filters[:diameter].present?
      filter_clauses << { term: { in_stock: true } } if filters[:in_stock].present?
      filter_clauses << { term: { supplier_id: filters[:supplier_id] } } if filters[:supplier_id].present?

      if filters[:price_min].present? || filters[:price_max].present?
        range = {}
        range[:gte] = filters[:price_min].to_f if filters[:price_min].present?
        range[:lte] = filters[:price_max].to_f if filters[:price_max].present?
        filter_clauses << { range: { price_uah: range } }
      end

      {
        query: {
          bool: {
            must: must_clauses.presence || [{ match_all: {} }],
            filter: filter_clauses
          }
        }
      }
    end

    def es_aggregations
      {
        brands: {
          terms: { field: 'brand_normalized', size: 50 }
        },
        seasons: {
          terms: { field: 'season', size: 10 }
        },
        widths: {
          terms: { field: 'width', size: 30, order: { _key: 'asc' } }
        },
        heights: {
          terms: { field: 'height', size: 30, order: { _key: 'asc' } }
        },
        diameters: {
          terms: { field: 'diameter', size: 30, order: { _key: 'asc' } }
        },
        price_range: {
          stats: { field: 'price_uah' }
        }
      }
    end

    def parse_aggregations(aggs)
      return {} if aggs.blank?

      {
        brands: aggs.dig('brands', 'buckets')&.map { |b| { name: b['key'], count: b['doc_count'] } } || [],
        seasons: aggs.dig('seasons', 'buckets')&.map { |b| { name: b['key'], count: b['doc_count'] } } || [],
        widths: aggs.dig('widths', 'buckets')&.map { |b| { value: b['key'], count: b['doc_count'] } } || [],
        heights: aggs.dig('heights', 'buckets')&.map { |b| { value: b['key'], count: b['doc_count'] } } || [],
        diameters: aggs.dig('diameters', 'buckets')&.map { |b| { value: b['key'], count: b['doc_count'] } } || [],
        price_range: {
          min: aggs.dig('price_range', 'min'),
          max: aggs.dig('price_range', 'max'),
          avg: aggs.dig('price_range', 'avg')&.round(2)
        }
      }
    end

    # Fallback to PostgreSQL search when Elasticsearch is unavailable
    def db_fallback_search(query, filters, page, per_page)
      scope = all
      scope = scope.search_by_text(query) if query.present?
      scope = scope.by_season(filters[:season]) if filters[:season].present?
      scope = scope.by_brand(filters[:brand_id]) if filters[:brand_id].present?
      scope = scope.where(width: filters[:width]) if filters[:width].present?
      scope = scope.where(height: filters[:height]) if filters[:height].present?
      scope = scope.where(diameter: filters[:diameter]) if filters[:diameter].present?
      scope = scope.in_stock if filters[:in_stock].present?
      scope = scope.where(supplier_id: filters[:supplier_id]) if filters[:supplier_id].present?

      if filters[:price_min].present?
        scope = scope.where('price_uah >= ?', filters[:price_min].to_f)
      end
      if filters[:price_max].present?
        scope = scope.where('price_uah <= ?', filters[:price_max].to_f)
      end

      total = scope.count
      offset = ([page.to_i, 1].max - 1) * per_page.to_i
      results = scope.order(optimality_score: :desc).offset(offset).limit(per_page.to_i)

      {
        results: results.to_a,
        total: total,
        facets: db_fallback_facets(filters)
      }
    end

    # Build facets from database when ES is not available
    def db_fallback_facets(filters)
      scope = in_stock
      scope = scope.by_season(filters[:season]) if filters[:season].present?
      scope = scope.by_brand(filters[:brand_id]) if filters[:brand_id].present?

      {
        brands: scope.group(:brand_normalized).count.map { |k, v| { name: k, count: v } }.sort_by { |h| -h[:count] },
        seasons: scope.group(:season).count.map { |k, v| { name: k, count: v } },
        widths: scope.group(:width).count.map { |k, v| { value: k, count: v } }.sort_by { |h| h[:value] },
        heights: scope.group(:height).count.map { |k, v| { value: k, count: v } }.sort_by { |h| h[:value] },
        diameters: scope.group(:diameter).count.map { |k, v| { value: k, count: v } }.sort_by { |h| h[:value] },
        price_range: {
          min: scope.minimum(:price_uah),
          max: scope.maximum(:price_uah),
          avg: scope.average(:price_uah)&.round(2)
        }
      }
    end
  end

  # Instance method: build the document for ES indexing
  def as_indexed_json(_options = {})
    {
      name: name,
      original_brand: original_brand,
      brand_normalized: brand_normalized,
      original_model: original_model,
      description: description,
      width: width,
      height: height,
      diameter: diameter,
      season: season,
      price_uah: price_uah,
      in_stock: in_stock,
      supplier_id: supplier_id,
      tire_brand_id: tire_brand_id,
      tire_model_id: tire_model_id,
      country_id: country_id,
      optimality_score: optimality_score,
      production_year: production_year,
      load_index: load_index,
      speed_index: speed_index,
      updated_at: updated_at
    }
  end
end
