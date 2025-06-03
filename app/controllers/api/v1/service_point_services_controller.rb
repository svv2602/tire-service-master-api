module Api
  module V1
    class ServicePointServicesController < ApiController
      skip_before_action :authenticate_request, only: [:index]
      before_action :set_service_point
      before_action :authorize_admin_or_partner, except: [:index]
      
      # GET /api/v1/service_points/:service_point_id/services
      def index
        @services = @service_point.services.includes(:category)
        
        # Фильтрация по категории
        if params[:category_id].present?
          @services = @services.where(category_id: params[:category_id])
        end
        
        # Фильтрация по активности
        if params[:active].present?
          @services = @services.where(is_active: params[:active] == 'true')
        end
        
        # Сортировка по умолчанию по имени
        @services = @services.order(:name)
        
        # Формируем JSON с текущими ценами для данной сервисной точки
        services_with_prices = @services.map do |service|
          service.as_json(include: :category).merge({
            current_price: service.current_price_for_service_point(@service_point.id)
          })
        end
        
        render json: services_with_prices
      end
      
      # POST /api/v1/service_points/:service_point_id/services
      def create
        # Проверяем, что услуга существует
        @service = Service.find(params[:service_id])
        
        # Проверяем, что услуга еще не добавлена к сервисной точке
        if @service_point.service_available?(params[:service_id])
          render json: { error: "Service is already added to this service point" }, status: :unprocessable_entity
          return
        end
        
        # Добавляем услугу к сервисной точке
        @service_point_service = ServicePointService.new(
          service_point_id: @service_point.id,
          service_id: params[:service_id]
        )
        
        if @service_point_service.save
          render json: @service.as_json(include: :category).merge({
            current_price: @service.current_price_for_service_point(@service_point.id)
          }), status: :created
        else
          render json: { errors: @service_point_service.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/service_points/:service_point_id/services/:id
      def destroy
        # Проверяем, что услуга добавлена к сервисной точке
        @service_point_service = ServicePointService.find_by(
          service_point_id: @service_point.id,
          service_id: params[:id]
        )
        
        if @service_point_service.nil?
          render json: { error: "Service is not added to this service point" }, status: :not_found
          return
        end
        
        # Проверяем, что услуга не используется в бронированиях
        if BookingService.joins(:booking)
                         .where(service_id: params[:id], bookings: { service_point_id: @service_point.id })
                         .exists?
          render json: { error: "Cannot remove service that is used in bookings" }, status: :unprocessable_entity
          return
        end
        
        if @service_point_service.destroy
          head :no_content
        else
          render json: { errors: @service_point_service.errors }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_service_point
        @service_point = ServicePoint.find(params[:service_point_id])
      end
      
      def authorize_admin_or_partner
        unless current_user && (current_user.admin? || 
                (current_user.role.name == 'operator' && @service_point.partner.user_id == current_user.id))
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end 