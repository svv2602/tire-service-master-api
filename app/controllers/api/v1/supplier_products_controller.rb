module Api
  module V1
    class SupplierProductsController < ApiController
      skip_after_action :verify_authorized
      before_action :authenticate_request
      before_action :ensure_supplier_access!
      before_action :set_supplier
      before_action :set_product, only: [:show, :update, :destroy, :toggle_active]

      # GET /api/v1/suppliers/:supplier_id/products
      def index
        @products = @supplier.supplier_tire_products

        # Apply filters
        @products = apply_filters(@products)

        # Sorting
        @products = apply_sorting(@products)

        result = paginate(@products)

        render json: {
          products: result[:data].map { |product| format_product(product) },
          pagination: result[:pagination],
          stats: products_stats
        }
      end

      # GET /api/v1/suppliers/:supplier_id/products/:id
      def show
        render json: {
          product: format_product_detailed(@product)
        }
      end

      # PATCH /api/v1/suppliers/:supplier_id/products/:id
      def update
        if @product.update(product_params)
          render json: {
            success: true,
            product: format_product(@product),
            message: 'Товар обновлён'
          }
        else
          render json: {
            success: false,
            errors: @product.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/suppliers/:supplier_id/products/:id
      # Soft delete - marks as not in stock
      def destroy
        @product.update!(in_stock: false, stock_status: 'archived')

        render json: {
          success: true,
          message: 'Товар архивирован'
        }
      end

      # POST /api/v1/suppliers/:supplier_id/products/:id/toggle_active
      def toggle_active
        new_status = !@product.in_stock
        @product.update!(
          in_stock: new_status,
          stock_status: new_status ? 'in_stock' : 'out_of_stock'
        )

        render json: {
          success: true,
          product: format_product(@product),
          message: new_status ? 'Товар активирован' : 'Товар деактивирован'
        }
      end

      # POST /api/v1/suppliers/:supplier_id/products/bulk_update
      # Mass update prices or availability
      def bulk_update
        updates = params[:updates]

        unless updates.is_a?(Array) && updates.present?
          return render json: {
            success: false,
            error: 'Параметр updates должен быть массивом'
          }, status: :bad_request
        end

        if updates.length > 100
          return render json: {
            success: false,
            error: 'Максимум 100 товаров за раз'
          }, status: :bad_request
        end

        results = { updated: 0, failed: 0, errors: [] }

        SupplierTireProduct.transaction do
          updates.each do |update_data|
            product = @supplier.supplier_tire_products.find_by(id: update_data[:id])

            if product.nil?
              results[:failed] += 1
              results[:errors] << { id: update_data[:id], error: 'Товар не найден' }
              next
            end

            permitted = update_data.slice(:price_uah, :in_stock, :stock_status).permit!

            if product.update(permitted)
              results[:updated] += 1
            else
              results[:failed] += 1
              results[:errors] << { id: update_data[:id], error: product.errors.full_messages.join(', ') }
            end
          end
        end

        render json: {
          success: results[:failed] == 0,
          results: results,
          message: "Обновлено: #{results[:updated]}, ошибок: #{results[:failed]}"
        }
      end

      private

      def ensure_supplier_access!
        unless current_user.admin? || current_user.supplier?
          render json: { error: 'Доступ запрещён' }, status: :forbidden
        end
      end

      def set_supplier
        @supplier = if current_user.admin?
                      Supplier.find(params[:supplier_id])
                    else
                      current_user.supplier
                    end

        render json: { error: 'Поставщик не найден' }, status: :not_found unless @supplier
      end

      def set_product
        @product = @supplier.supplier_tire_products.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Товар не найден' }, status: :not_found
      end

      def product_params
        params.require(:product).permit(
          :price_uah,
          :in_stock,
          :stock_status,
          :description
        )
      end

      def apply_filters(products)
        # Filter by brand
        products = products.where(brand_normalized: params[:brand]) if params[:brand].present?

        # Filter by season
        products = products.by_season(params[:season]) if params[:season].present?

        # Filter by stock
        if params[:in_stock].present?
          products = params[:in_stock] == 'true' ? products.in_stock : products.where(in_stock: false)
        end

        # Search by text
        products = products.search_by_text(params[:search]) if params[:search].present?

        # Filter by size
        products = products.where(width: params[:width]) if params[:width].present?
        products = products.where(height: params[:height]) if params[:height].present?
        products = products.where(diameter: params[:diameter]) if params[:diameter].present?

        products
      end

      def apply_sorting(products)
        case params[:sort]
        when 'price_asc'
          products.order(Arel.sql('price_uah ASC NULLS LAST'))
        when 'price_desc'
          products.order(Arel.sql('price_uah DESC NULLS LAST'))
        when 'name'
          products.order(:brand_normalized, :original_model)
        when 'updated_at'
          products.order(updated_at: :desc)
        else
          products.order(created_at: :desc)
        end
      end

      def products_stats
        {
          total: @supplier.supplier_tire_products.count,
          in_stock: @supplier.supplier_tire_products.in_stock.count,
          out_of_stock: @supplier.supplier_tire_products.where(in_stock: false).count,
          brands_count: @supplier.supplier_tire_products.distinct.count(:brand_normalized)
        }
      end

      def format_product(product)
        {
          id: product.id,
          external_id: product.external_id,
          brand: product.brand_normalized,
          original_brand: product.original_brand,
          model: product.original_model,
          name: product.name,
          size: product.tire_size,
          width: product.width,
          height: product.height,
          diameter: product.diameter,
          load_index: product.load_index,
          speed_index: product.speed_index,
          season: product.season,
          price_uah: product.price_uah&.to_f,
          in_stock: product.in_stock,
          stock_status: product.stock_status,
          image_url: product.image_url,
          updated_at: product.updated_at.strftime('%d.%m.%Y %H:%M')
        }
      end

      def format_product_detailed(product)
        format_product(product).merge(
          description: product.description,
          product_url: product.product_url,
          country: product.original_country,
          year_week: product.year_week,
          created_at: product.created_at.strftime('%d.%m.%Y %H:%M'),
          orders_count: product.tire_order_items.count,
          total_sold: product.tire_order_items.sum(:quantity)
        )
      end
    end
  end
end
