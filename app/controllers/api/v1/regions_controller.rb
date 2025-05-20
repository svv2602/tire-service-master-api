module Api
  module V1
    class RegionsController < ApiController
      before_action :set_region, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:index, :show]
      skip_before_action :authenticate_request, only: [:index, :show]
      
      # GET /api/v1/regions
      def index
        @regions = Region.all
        
        # Фильтрация
        @regions = @regions.where(is_active: true) if params[:active].present? && params[:active] == 'true'
        
        # Поиск по названию
        if params[:query].present?
          @regions = @regions.where("name LIKE ?", "%#{params[:query]}%")
        end
        
        # Сортировка
        @regions = @regions.order(params[:sort] || :name)
        
        # Пагинация
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        offset = (page - 1) * per_page
        
        total_count = @regions.count
        @regions = @regions.offset(offset).limit(per_page)
        
        render json: {
          regions: @regions,
          total_items: total_count
        }
      end
      
      # GET /api/v1/regions/:id
      def show
        render json: @region
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
        params.require(:region).permit(:name, :code, :is_active)
      end
      
      def authorize_admin
        unless current_user && current_user.admin?
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end 