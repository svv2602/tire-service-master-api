module Api
  module V1
    class RegionsController < ApiController
      before_action :set_region, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:index, :show]
      skip_before_action :authenticate_request, only: [:index, :show]
      
      # GET /api/v1/regions
      def index
        @regions = Region.includes(:cities).order(:name)
        
        # Фильтрация по поиску
        if params[:search].present?
          @regions = @regions.where("name ILIKE ?", "%#{params[:search]}%")
        end
        
        # Фильтрация по статусу активности
        if params[:is_active].present?
          @regions = @regions.where(is_active: params[:is_active])
        end
        
        # Пагинация
        page = [params[:page].to_i, 1].max  # Минимум 1
        per_page = (params[:per_page] || 25).to_i
        offset = (page - 1) * per_page
        
        total_count = @regions.count
        @regions = @regions.offset(offset).limit(per_page)
        
        render json: {
          data: @regions.as_json(include: { 
            cities: { only: [:id, :name], where: { is_active: true } }
          }),
          pagination: {
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil,
            current_page: page,
            per_page: per_page
          }
        }
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