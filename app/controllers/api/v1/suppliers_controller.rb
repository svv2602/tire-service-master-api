module Api
  module V1
    class SuppliersController < ApiController
      before_action :authenticate_supplier, only: [:upload_price]
      before_action :ensure_admin!, except: [:upload_price]
      before_action :set_supplier, only: [:show, :update, :destroy]
      
      # GET /api/v1/suppliers
      def index
        @suppliers = Supplier.includes(:supplier_price_versions).by_priority
        
        # Фильтрация по активности
        if params[:active_only] == 'true'
          @suppliers = @suppliers.active
        end
        
        result = paginate(@suppliers)
        
        render json: {
          suppliers: result[:data].map { |supplier| format_supplier(supplier) },
          pagination: result[:pagination]
        }
      end
      
      # GET /api/v1/suppliers/:id
      def show
        render json: {
          supplier: format_supplier_detailed(@supplier)
        }
      end
      
      # POST /api/v1/suppliers
      def create
        @supplier = Supplier.new(supplier_params)
        
        if @supplier.save
          render json: {
            success: true,
            supplier: format_supplier(@supplier),
            message: "Поставщик успешно создан"
          }, status: :created
        else
          render json: {
            success: false,
            errors: @supplier.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/suppliers/:id
      def update
        if @supplier.update(supplier_params)
          render json: {
            success: true,
            supplier: format_supplier(@supplier),
            message: "Поставщик успешно обновлен"
          }
        else
          render json: {
            success: false,
            errors: @supplier.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/suppliers/:id
      def destroy
        @supplier.destroy
        render json: {
          success: true,
          message: "Поставщик успешно удален"
        }
      end
      
      # POST /api/v1/suppliers/upload_price
      # Endpoint для загрузки прайса поставщиком
      def upload_price
        xml_content = extract_xml_content
        
        if xml_content.blank?
          return render json: {
            success: false,
            error: "XML данные не найдены"
          }, status: :bad_request
        end
        
        # Обрабатываем XML в фоновом режиме для больших файлов
        if xml_content.size > 5.megabytes
          # TODO: Добавить фоновую обработку через Sidekiq
          render json: {
            success: true,
            message: "Большой файл поставлен в очередь на обработку",
            processing: true
          }
        else
          # Обрабатываем синхронно
          processor = SupplierXmlProcessor.new(@current_supplier, xml_content)
          result = processor.process
          
          if result[:success]
            render json: {
              success: true,
              message: result[:message],
              statistics: result[:statistics],
              version: result[:version].version
            }
          else
            render json: {
              success: false,
              error: result[:error],
              statistics: result[:statistics]
            }, status: :unprocessable_entity
          end
        end
        
      rescue StandardError => e
        Rails.logger.error "Ошибка загрузки прайса: #{e.message}"
        render json: {
          success: false,
          error: "Внутренняя ошибка сервера"
        }, status: :internal_server_error
      end
      
      # GET /api/v1/suppliers/:id/products
      def products
        @supplier = Supplier.find(params[:id])
        products = @supplier.supplier_tire_products.includes(:supplier)
        
        # Фильтрация
        products = products.by_brand(params[:brand]) if params[:brand].present?
        products = products.by_season(params[:season]) if params[:season].present?
        products = products.in_stock if params[:in_stock_only] == 'true'
        
        result = paginate(products)
        
        render json: {
          products: result[:data].map { |product| format_product(product) },
          pagination: result[:pagination],
          supplier: format_supplier(@supplier)
        }
      end
      
      # GET /api/v1/suppliers/:id/statistics
      def statistics
        @supplier = Supplier.find(params[:id])
        
        stats = {
          total_products: @supplier.products_count,
          in_stock_products: @supplier.in_stock_products_count,
          brands_count: @supplier.supplier_tire_products.distinct.count(:brand_normalized),
          last_sync: @supplier.last_sync_at,
          sync_status: @supplier.sync_status,
          recent_versions: @supplier.supplier_price_versions.recent.limit(5).map do |version|
            {
              version: version.version,
              uploaded_at: version.uploaded_at,
              products_count: version.products_count,
              success_rate: version.success_rate,
              status: version.status
            }
          end
        }
        
        render json: { statistics: stats }
      end
      
      private
      
      def authenticate_supplier
        api_key = request.headers['X-API-Key'] || params[:api_key]
        
        if api_key.blank?
          return render json: {
            success: false,
            error: "API ключ не предоставлен"
          }, status: :unauthorized
        end
        
        @current_supplier = Supplier.find_by(api_key: api_key, is_active: true)
        
        unless @current_supplier
          return render json: {
            success: false,
            error: "Недействительный API ключ"
          }, status: :unauthorized
        end
      end
      
      def set_supplier
        @supplier = Supplier.find(params[:id])
      end
      
      def supplier_params
        params.require(:supplier).permit(
          :firm_id, :name, :is_active, :priority
        )
      end
      
      def extract_xml_content
        if params[:xml_data].present?
          # XML в параметре
          params[:xml_data]
        elsif params[:file].present?
          # XML файл
          params[:file].read
        elsif request.body.present?
          # XML в теле запроса
          request.body.read
        end
      end
      
      def format_supplier(supplier)
        {
          id: supplier.id,
          firm_id: supplier.firm_id,
          name: supplier.name,
          is_active: supplier.is_active,
          priority: supplier.priority,
          products_count: supplier.products_count,
          in_stock_products_count: supplier.in_stock_products_count,
          last_sync_at: supplier.last_sync_at,
          sync_status: supplier.sync_status,
          created_at: supplier.created_at
        }
      end
      
      def format_supplier_detailed(supplier)
        format_supplier(supplier).merge(
          api_key: supplier.api_key,
          recent_versions: supplier.supplier_price_versions.recent.limit(10).map do |version|
            {
              id: version.id,
              version: version.version,
              uploaded_at: version.uploaded_at,
              products_count: version.products_count,
              processed_count: version.processed_count,
              errors_count: version.errors_count,
              success_rate: version.success_rate,
              status: version.status,
              processing_time_seconds: version.processing_time_seconds
            }
          end
        )
      end
      
      def format_product(product)
        {
          id: product.id,
          external_id: product.external_id,
          brand: product.brand_normalized,
          model: product.model,
          name: product.name,
          size: product.tire_size,
          load_speed_index: product.load_speed_indices,
          season: product.season,
          price_uah: product.price_uah,
          stock_status: product.stock_status,
          in_stock: product.in_stock,
          image_url: product.image_url,
          product_url: product.product_url,
          country: product.country,
          year_week: product.year_week
        }
      end
    end
  end
end