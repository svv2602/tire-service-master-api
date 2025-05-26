module Api
  module V1
    class RegionsController < ApiController
      before_action :set_region, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:index, :show]
      skip_before_action :authenticate_request, only: [:index, :show]
      
      # GET /api/v1/regions
      def index
        @regions = Region.includes(:cities).where(is_active: true).order(:name)
        
        render json: @regions.as_json(include: { 
          cities: { only: [:id, :name], where: { is_active: true } }
        })
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