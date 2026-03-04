# frozen_string_literal: true

# Concern that adds sparse fieldset support for API responses.
# Allows clients to request only specific fields via ?fields=id,name,address
# This reduces payload size — critical for mobile apps on slow connections.
#
# Usage in controllers:
#   include SparseFieldsets
#
#   def index
#     render json: apply_sparse_fieldsets(serialized_data)
#   end
#
# Query parameter format:
#   GET /api/v1/service_points?fields=id,name,address
#   GET /api/v1/bookings?fields=id,status,booking_date
module SparseFieldsets
  extend ActiveSupport::Concern

  private

  # Parse requested fields from the `fields` query parameter.
  # Returns nil if no sparse fieldset was requested.
  # @return [Array<String>, nil]
  def requested_fields
    return @requested_fields if defined?(@requested_fields)

    raw = params[:fields]
    @requested_fields = if raw.present?
      raw.to_s.split(',').map(&:strip).reject(&:blank?)
    end
  end

  # Returns true if the client requested sparse fields
  def sparse_fields_requested?
    requested_fields.present?
  end

  # Filter a hash (or array of hashes) to include only the requested fields.
  # Always preserves :id / "id" if present in original data.
  # Returns data unchanged when no fields param is specified.
  #
  # @param data [Hash, Array<Hash>, ActiveModel::Serializer] serialized data
  # @return [Hash, Array<Hash>]
  def apply_sparse_fieldsets(data)
    return data unless sparse_fields_requested?

    fields = requested_fields.map(&:to_s)
    # Always include 'id' when sparse fields are used
    fields << 'id' unless fields.include?('id')

    case data
    when Array
      data.map { |item| filter_hash(item, fields) }
    when Hash
      # If hash has a :data key (paginated response), filter inside
      if data.key?(:data) || data.key?('data')
        key = data.key?(:data) ? :data : 'data'
        filtered = data[key].is_a?(Array) ? data[key].map { |item| filter_hash(item, fields) } : filter_hash(data[key], fields)
        data.merge(key => filtered)
      else
        filter_hash(data, fields)
      end
    else
      data
    end
  end

  # Filter a single hash to only include specified field keys
  # @param hash [Hash] original hash
  # @param fields [Array<String>] allowed field names
  # @return [Hash]
  def filter_hash(hash, fields)
    return hash unless hash.is_a?(Hash)

    hash.select { |key, _| fields.include?(key.to_s) }
  end
end
