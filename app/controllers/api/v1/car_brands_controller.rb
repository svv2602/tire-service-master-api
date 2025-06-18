module Api
  module V1
    class CarBrandsController < ApiController
      before_action :set_car_brand, only: [:show, :update, :destroy]
      before_action :authorize_admin, except: [:index, :show]
      skip_before_action :authenticate_request, only: [:index, :show]
      
      # GET /api/v1/car_brands
      def index
        @car_brands = CarBrand.all
        
        # Фильтрация
        @car_brands = @car_brands.where(is_active: true) if params[:active].present? && params[:active] == 'true'
        
        # Поиск по названию
        if params[:query].present?
          @car_brands = @car_brands.where("LOWER(name) LIKE LOWER(?)", "%#{params[:query]}%")
        end
        
        # Сортировка
        @car_brands = @car_brands.order(params[:sort] || :name)
        
        # Пагинация
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 25).to_i
        offset = (page - 1) * per_page
        
        total_count = @car_brands.count
        @car_brands = @car_brands.offset(offset).limit(per_page)
        
        render json: {
          car_brands: @car_brands.map { |brand| brand_json(brand) },
          total_items: total_count
        }
      end
      
      # GET /api/v1/car_brands/:id
      def show
        render json: brand_json(@car_brand, include_models: true)
      end
      
      # POST /api/v1/car_brands
      def create
        Rails.logger.info "=== CarBrandsController#create ==="
        Rails.logger.info "Content Type: #{request.content_type}"
        Rails.logger.info "Raw params: #{params.inspect}"
        
        @car_brand = CarBrand.new(car_brand_params)
        
        if @car_brand.save
          Rails.logger.info "Brand created successfully: #{@car_brand.id}"
          render json: brand_json(@car_brand), status: :created
        else
          Rails.logger.error "Brand creation failed: #{@car_brand.errors.full_messages}"
          render json: { errors: @car_brand.errors }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "Error in create: #{e.class}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
      end
      
      # PUT /api/v1/car_brands/:id
      def update
        Rails.logger.info "=== CarBrandsController#update ==="
        Rails.logger.info "Content Type: #{request.content_type}"
        Rails.logger.info "Raw params: #{params.inspect}"
        Rails.logger.info "car_brand params: #{params[:car_brand].inspect}"
        
        # Обрабатываем удаление логотипа
        if params[:car_brand]&.dig(:logo) == 'null' || params[:car_brand]&.dig(:logo) == nil
          Rails.logger.info "Removing logo"
          @car_brand.logo.purge if @car_brand.logo.attached?
        end

        # Проверяем, есть ли новый файл логотипа
        if params[:car_brand]&.dig(:logo).respond_to?(:read)
          Rails.logger.info "New logo file detected: #{params[:car_brand][:logo].original_filename}"
        end

        if @car_brand.update(car_brand_params)
          Rails.logger.info "Brand updated successfully"
          render json: brand_json(@car_brand)
        else
          Rails.logger.error "Brand update failed: #{@car_brand.errors.full_messages}"
          render json: { errors: @car_brand.errors }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "Error in update: #{e.class}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
      end
      
      # DELETE /api/v1/car_brands/:id
      def destroy
        if @car_brand.client_cars.exists?
          render json: { error: 'Невозможно удалить бренд, так как он используется в автомобилях клиентов' }, status: :unprocessable_entity
        else
          @car_brand.logo.purge if @car_brand.logo.attached?
          @car_brand.destroy
          head :no_content
        end
      end
      
      private
      
      def set_car_brand
        @car_brand = CarBrand.find(params[:id])
      end
      
      def car_brand_params
        permitted_params = params.require(:car_brand).permit(:name, :logo, :is_active)
        
        # Если логотип пустой или null, исключаем его из параметров
        if permitted_params[:logo].blank? || permitted_params[:logo] == 'null'
          permitted_params.except(:logo)
        else
          permitted_params
        end
      end
      
      def authorize_admin
        unless current_user && current_user.admin?
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end

      def brand_json(brand, include_models: false)
        json = brand.as_json(
          only: [:id, :name, :is_active]
        )

        # Добавляем дату создания и обновления в ISO8601
        json['created_at'] = brand.created_at&.iso8601
        json['updated_at'] = brand.updated_at&.iso8601

        # Добавляем URL логотипа, если он есть
        if brand.logo.attached?
          json['logo'] = Rails.application.routes.url_helpers.rails_blob_url(
            brand.logo,
            host: request.base_url
          )
        else
          json['logo'] = nil
        end

        # Добавляем количество моделей (гарантированно присутствует)
        json['models_count'] = brand.car_models.count

        # Добавляем модели, если требуется
        if include_models
          json['car_models'] = brand.car_models.map do |model|
            model.as_json(only: [:id, :name, :is_active])
          end
        end

        json
      end
    end
  end
end 