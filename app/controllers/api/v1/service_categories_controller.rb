module Api
  module V1
    class ServiceCategoriesController < ApiController
      skip_before_action :authenticate_request, only: [:index, :show]
      before_action :set_service_category, only: [:show, :update, :destroy]
      before_action :authorize_admin!, only: [:create, :update, :destroy]
      
      # GET /api/v1/service_categories
      def index
        @service_categories = ServiceCategory.active.sorted
        render json: @service_categories
      end
      
      # GET /api/v1/service_categories/:id
      def show
        render json: @service_category.as_json(include: {
          services: { only: [:id, :name, :default_duration, :is_active] }
        })
      end
      
      # POST /api/v1/service_categories
      def create
        @service_category = ServiceCategory.new(service_category_params)
        
        if @service_category.save
          render json: @service_category, status: :created
        else
          render json: { error: @service_category.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/service_categories/:id
      def update
        if @service_category.update(service_category_params)
          render json: @service_category
        else
          render json: { error: @service_category.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/service_categories/:id
      def destroy
        if @service_category.destroy
          head :no_content
        else
          render json: { error: 'Невозможно удалить категорию, которая содержит услуги' }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_service_category
        @service_category = ServiceCategory.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Категория услуг не найдена' }, status: :not_found
      end
      
      def service_category_params
        params.require(:service_category).permit(:name, :description, :is_active, :sort_order)
      end
      
      def authorize_admin!
        unless current_user&.role == 'admin'
          render json: { error: 'Доступ запрещен' }, status: :forbidden
        end
      end
    end
  end
end 