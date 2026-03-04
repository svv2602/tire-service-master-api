# frozen_string_literal: true

module Api
  module V1
    class AmenitiesController < ApiController
      before_action :authenticate_request
      skip_before_action :authenticate_request, only: [:index, :show]
      before_action :set_amenity, only: [:show, :destroy]
      before_action :set_service_point, only: [:create, :destroy], if: -> { params[:service_point_id].present? }
      skip_after_action :verify_authorized

      # GET /api/v1/amenities
      # GET /api/v1/service_points/:service_point_id/amenities
      def index
        if params[:service_point_id].present?
          # Per-service-point amenities: not cached (scoped, low volume)
          service_point = ServicePoint.find(params[:service_point_id])
          @amenities = service_point.amenities
          render json: { data: @amenities.map { |a| format_amenity(a) } }
        else
          # Global amenities list: cached with versioned key
          cache_key = CacheVersioning.versioned_key("amenities:index:all", "amenities")

          result = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
            { data: Amenity.all.order(:name).map { |a| format_amenity(a) } }
          end

          render json: result
        end
      end

      # GET /api/v1/amenities/:id
      def show
        render json: { data: format_amenity(@amenity) }
      end

      # POST /api/v1/service_points/:service_point_id/amenities
      def create
        return render json: { error: 'service_point_id is required' }, status: :bad_request unless @service_point

        amenity = Amenity.find_by(id: params[:amenity_id])
        return render json: { error: 'Amenity not found' }, status: :not_found unless amenity

        unless @service_point.amenities.include?(amenity)
          @service_point.amenities << amenity
        end

        render json: { data: format_amenity(amenity), message: 'Amenity added to service point' }, status: :created
      end

      # DELETE /api/v1/service_points/:service_point_id/amenities/:id
      def destroy
        if @service_point
          @service_point.amenities.delete(@amenity)
          render json: { message: 'Amenity removed from service point' }
        else
          @amenity.destroy
          render json: { message: 'Amenity deleted' }
        end
      end

      private

      def set_amenity
        @amenity = Amenity.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Amenity not found' }, status: :not_found
      end

      def set_service_point
        @service_point = ServicePoint.find(params[:service_point_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Service point not found' }, status: :not_found
      end

      def format_amenity(amenity)
        {
          id: amenity.id,
          name: amenity.name,
          created_at: amenity.created_at,
          updated_at: amenity.updated_at
        }
      end
    end
  end
end
