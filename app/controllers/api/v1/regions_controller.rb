module Api
  module V1
    class RegionsController < ApiController
      before_action :set_region, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:index, :show]
      skip_before_action :authenticate_request, only: [:index, :show]
      skip_after_action :verify_authorized
      
      # GET /api/v1/regions
      def index
        cache_key = CacheVersioning.versioned_key(
          "regions:index:#{regions_cache_params_key}",
          "regions"
        )

        result = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
          @regions = Region.includes(:cities).order(:name)

          # Filter by search (search across all locale fields)
          if params[:search].present?
            search_term = "%#{params[:search]}%"
            @regions = @regions.where(
              "name ILIKE ? OR name_ru ILIKE ? OR name_uk ILIKE ?",
              search_term, search_term, search_term
            )
          end

          # Filter by active status
          if params[:is_active].present?
            @regions = @regions.where(is_active: params[:is_active])
          end

          # Pagination
          page = [params[:page].to_i, 1].max
          per_page = (params[:per_page] || 25).to_i
          offset = (page - 1) * per_page

          total_count = @regions.count
          @regions = @regions.offset(offset).limit(per_page)

          locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'

          {
            data: ActiveModel::Serializer::CollectionSerializer.new(
              @regions,
              serializer: RegionSerializer,
              locale: locale
            ),
            pagination: {
              total_count: total_count,
              total_pages: (total_count.to_f / per_page).ceil,
              current_page: page,
              per_page: per_page
            }
          }
        end

        render json: result
      end
      
      # GET /api/v1/regions/:id
      def show
        @region = Region.includes(:cities).find(params[:id])
        
        render json: @region.as_json(include: { 
          cities: { only: [:id, :name], where: { is_active: true } }
        })
      rescue ActiveRecord::RecordNotFound
        render json: { 
          error: "Регион с ID #{params[:id]} не найден",
          message: "Регион с указанным идентификатором не существует в системе."
        }, status: :not_found
      end
      
      # POST /api/v1/regions
      def create
        @region = Region.new(region_params)
        
        if @region.save
          render json: @region, status: :created
        else
          render json: { errors: @region.errors }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/regions/:id
      def update
        if @region.update(region_params)
          render json: @region
        else
          render json: { errors: @region.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/regions/:id
      def destroy
        if @region.cities.exists?
          render json: { error: 'Невозможно удалить регион, так как он содержит города' }, status: :unprocessable_entity
        else
          @region.destroy
          head :no_content
        end
      end
      
      private
      
      def set_region
        @region = Region.find(params[:id])
      end
      
      def region_params
        params.require(:region).permit(:name, :name_ru, :name_uk, :code, :is_active)
      end
      
      def authorize_admin
        unless current_user && current_user.admin?
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end

      def regions_cache_params_key
        locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first || 'ru'
        [
          params[:search],
          params[:is_active],
          params[:page],
          params[:per_page],
          locale
        ].compact.join(':')
      end
    end
  end
end