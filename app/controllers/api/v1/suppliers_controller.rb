module Api
  module V1
    class SuppliersController < ApiController
      skip_before_action :authenticate_request, only: [:all_products]
      before_action :authenticate_supplier, only: [:upload_price]
      before_action :ensure_admin!, except: [:upload_price, :all_products]
      before_action :set_supplier, only: [:show, :update, :destroy, :admin_upload_price, :regenerate_api_key, :price_versions]
      
      # GET /api/v1/suppliers
      def index
        @suppliers = Supplier.includes(:supplier_price_versions).by_priority
        
        # Фильтрация по активности
        if params[:active_only] == 'true'
          @suppliers = @suppliers.active
        end
        
        # Поиск по названию и firm_id (без учета регистра)
        if params[:search].present?
          @suppliers = @suppliers.search(params[:search])
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
      
      # POST /api/v1/suppliers/:id/upload_price  
      # Endpoint для загрузки прайса администратором
      def admin_upload_price
        @supplier = Supplier.find(params[:id])
        xml_content = extract_xml_content
        
        if xml_content.blank?
          return render json: {
            success: false,
            error: "XML данные не найдены"
          }, status: :bad_request
        end
        
        # Проверяем размер файла
        file_size_mb = (xml_content.size / 1.megabyte).round(2)
        Rails.logger.info "📁 Загружен файл размером #{file_size_mb}MB для поставщика #{@supplier.name}"
        
        if xml_content.size > 25.megabytes
          # Файл слишком большой для синхронной обработки
          render json: {
            success: false,
            error: "Файл слишком большой (#{file_size_mb}MB). Максимальный размер: 25MB",
            file_size_mb: file_size_mb,
            max_size_mb: 25,
            suggestion: "Разделите прайс-лист на несколько файлов или обратитесь к администратору"
          }, status: :payload_too_large
        else
          # Обрабатываем синхронно
          Rails.logger.info "🔄 Начинаем синхронную обработку файла #{file_size_mb}MB"
          processor = SupplierXmlProcessor.new(@supplier, xml_content)
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
        Rails.logger.error "Ошибка загрузки прайса админом: #{e.message}"
        render json: {
          success: false,
          error: "Внутренняя ошибка сервера"
        }, status: :internal_server_error
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
        
        # Проверяем размер файла
        file_size_mb = (xml_content.size / 1.megabyte).round(2)
        Rails.logger.info "📁 Загружен файл размером #{file_size_mb}MB от поставщика #{@current_supplier.name}"
        
        if xml_content.size > 25.megabytes
          # Файл слишком большой для синхронной обработки
          render json: {
            success: false,
            error: "Файл слишком большой (#{file_size_mb}MB). Максимальный размер: 25MB",
            file_size_mb: file_size_mb,
            max_size_mb: 25,
            suggestion: "Разделите прайс-лист на несколько файлов или обратитесь к администратору"
          }, status: :payload_too_large
        else
          # Обрабатываем синхронно
          Rails.logger.info "🔄 Начинаем синхронную обработку файла #{file_size_mb}MB"
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
        
        # Поиск по тексту (название, бренд, модель, ID, описание)
        products = products.search_by_text(params[:search]) if params[:search].present?
        
        # Фильтрация по дате обновления
        if params[:updated_after].present?
          begin
            date = Date.parse(params[:updated_after])
            products = products.updated_after(date.beginning_of_day)
          rescue ArgumentError
            Rails.logger.warn "Invalid date format for updated_after: #{params[:updated_after]}"
          end
        end
        
        if params[:updated_before].present?
          begin
            date = Date.parse(params[:updated_before])
            products = products.updated_before(date.end_of_day)
          rescue ArgumentError
            Rails.logger.warn "Invalid date format for updated_before: #{params[:updated_before]}"
          end
        end
        
        # Сортировка по дате обновления (новые сначала) или по умолчанию
        products = if params[:sort_by] == 'updated_at'
          products.order(updated_at: :desc)
        else
          products.order(:brand_normalized, :model, :price_uah)
        end
        
        result = paginate(products)
        
        render json: {
          products: result[:data].map { |product| format_product(product) },
          pagination: result[:pagination],
          supplier: format_supplier(@supplier)
        }
      end
      
      # GET /api/v1/suppliers/products/all
      # Получение товаров всех поставщиков (для клиентов)
      def all_products
        products = SupplierTireProduct.includes(:supplier)
        
        # Фильтрация
        products = products.by_brand(params[:brand]) if params[:brand].present?
        products = products.by_season(params[:season]) if params[:season].present?
        products = products.in_stock if params[:in_stock_only] == 'true'
        
        # Фильтрация по размерам
        products = products.where(width: params[:width]) if params[:width].present?
        products = products.where(height: params[:height]) if params[:height].present?
        products = products.where(diameter: params[:diameter]) if params[:diameter].present?
        
        # Поиск по тексту (название, бренд, модель, ID, описание)
        products = products.search_by_text(params[:search]) if params[:search].present?
        
        # Фильтрация по дате обновления
        if params[:updated_after].present?
          begin
            date = Date.parse(params[:updated_after])
            products = products.updated_after(date.beginning_of_day)
          rescue ArgumentError
            Rails.logger.warn "Invalid date format for updated_after: #{params[:updated_after]}"
          end
        end
        
        if params[:updated_before].present?
          begin
            date = Date.parse(params[:updated_before])
            products = products.updated_before(date.end_of_day)
          rescue ArgumentError
            Rails.logger.warn "Invalid date format for updated_before: #{params[:updated_before]}"
          end
        end
        
        # Сортировка
        products = case params[:sort_by]
                   when 'price_asc'
                     products.order(Arel.sql('price_uah ASC NULLS LAST'))
                   when 'price_desc'
                     products.order(Arel.sql('price_uah DESC NULLS LAST'))
                   when 'updated_at'
                     products.order(updated_at: :desc)
                   when 'supplier_name'
                     products.joins(:supplier).order('suppliers.name ASC')
                   else
                     products.order(:brand_normalized, :model, :price_uah)
                   end
        
        result = paginate(products)
        
        render json: {
          products: result[:data].map { |product| format_product_with_supplier(product) },
          pagination: result[:pagination]
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
      
      # PATCH /api/v1/suppliers/:id/regenerate_api_key
      def regenerate_api_key
        begin
          old_api_key = @supplier.api_key
          @supplier.regenerate_api_key!
          
          Rails.logger.info "API ключ поставщика #{@supplier.name} (ID: #{@supplier.id}) регенерирован. Старый: #{old_api_key[0..8]}..., Новый: #{@supplier.api_key[0..8]}..."
          
          render json: {
            success: true,
            supplier: format_supplier_detailed(@supplier),
            message: "API ключ успешно регенерирован"
          }
        rescue StandardError => e
          Rails.logger.error "Ошибка регенерации API ключа для поставщика ID #{@supplier.id}: #{e.message}"
          
          render json: {
            success: false,
            message: "Ошибка при регенерации API ключа",
            error: e.message
          }, status: :internal_server_error
        end
      end
      
      # GET /api/v1/suppliers/:id/price_versions
      def price_versions
        versions = @supplier.supplier_price_versions.order(uploaded_at: :desc)
        
        result = paginate(versions)
        
        render json: {
          data: result[:data].map { |version| format_price_version(version) },
          meta: result[:pagination]
        }
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
          width: product.width,
          height: product.height,
          diameter: product.diameter,
          load_index: product.load_index,
          speed_index: product.speed_index,
          size: product.tire_size,
          load_speed_index: product.load_speed_indices,
          season: product.season,
          price_uah: product.price_uah,
          stock_status: product.stock_status,
          in_stock: product.in_stock,
          description: product.description,
          image_url: product.image_url,
          product_url: product.product_url,
          country: product.country,
          year_week: product.year_week,
          updated_at: product.updated_at&.strftime('%Y-%m-%d %H:%M')
        }
      end

      def format_product_with_supplier(product)
        {
          id: product.id,
          external_id: product.external_id,
          brand: product.brand_normalized,
          model: product.model,
          name: product.name,
          width: product.width,
          height: product.height,
          diameter: product.diameter,
          load_index: product.load_index,
          speed_index: product.speed_index,
          size: product.tire_size,
          load_speed_index: product.load_speed_indices,
          season: product.season,
          price_uah: product.price_uah,
          stock_status: product.stock_status,
          in_stock: product.in_stock,
          description: product.description,
          image_url: product.image_url,
          product_url: product.product_url,
          country: product.country,
          year_week: product.year_week,
          updated_at: product.updated_at&.strftime('%Y-%m-%d %H:%M'),
          supplier: {
            id: product.supplier.id,
            name: product.supplier.name,
            firm_id: product.supplier.firm_id,
            priority: product.supplier.priority,
            is_active: product.supplier.is_active
          }
        }
      end
      
      def format_price_version(version)
        processing_time_seconds = if version.processing_time_ms
          (version.processing_time_ms / 1000.0).round(2)
        else
          nil
        end
        
        success_rate = if version.products_count && version.products_count > 0
          ((version.processed_count || 0).to_f / version.products_count * 100).round(2)
        else
          0.0
        end
        
        {
          id: version.id,
          version: version.version,
          uploaded_at: version.uploaded_at&.strftime('%Y-%m-%d %H:%M:%S'),
          file_checksum: version.file_checksum,
          products_count: version.products_count || 0,
          processed_count: version.processed_count || 0,
          errors_count: version.errors_count || 0,
          success_rate: success_rate,
          status: determine_version_status(version),
          processing_time_seconds: processing_time_seconds
        }
      end
      
      def determine_version_status(version)
        return 'pending' if version.processed_count == 0 && version.errors_count == 0
        return 'failed' if version.errors_count > 0 && version.processed_count == 0
        return 'completed' if version.processed_count > 0
        'processing'
      end
    end
  end
end