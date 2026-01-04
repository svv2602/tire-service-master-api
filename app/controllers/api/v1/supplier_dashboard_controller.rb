module Api
  module V1
    class SupplierDashboardController < ApiController
      include HttpCacheable

      before_action :authenticate_request
      before_action :ensure_supplier_access!
      before_action :set_supplier
      skip_before_action :set_cache_headers # Use custom caching

      # GET /api/v1/suppliers/:supplier_id/dashboard
      def show
        cache_for(60) # Private cache for 1 minute
        vary_on('Authorization')
        render json: {
          stats: cached_stats,
          recent_orders: recent_orders_data,
          top_products: cached_top_products,
          revenue_chart: cached_revenue_chart
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

      def cached_stats
        Rails.cache.fetch("supplier_dashboard_stats_#{@supplier.id}", expires_in: 5.minutes) do
          calculate_stats
        end
      end

      def cached_top_products
        Rails.cache.fetch("supplier_top_products_#{@supplier.id}", expires_in: 5.minutes) do
          calculate_top_products
        end
      end

      def cached_revenue_chart
        Rails.cache.fetch("supplier_revenue_chart_#{@supplier.id}", expires_in: 5.minutes) do
          calculate_revenue_chart
        end
      end

      def calculate_stats
        orders = @supplier.tire_orders.where.not(status: 'draft')
        completed_orders = orders.completed

        {
          # Orders stats
          total_orders: orders.count,
          pending_orders: orders.pending.count,
          processing_orders: orders.processing.count,
          completed_orders: completed_orders.count,
          cancelled_orders: orders.cancelled.count,

          # Revenue
          total_revenue: completed_orders.sum(:total_amount).to_f,
          monthly_revenue: completed_orders.where('created_at >= ?', 30.days.ago).sum(:total_amount).to_f,
          weekly_revenue: completed_orders.where('created_at >= ?', 7.days.ago).sum(:total_amount).to_f,

          # Products stats
          total_products: @supplier.supplier_tire_products.count,
          in_stock_products: @supplier.supplier_tire_products.where(in_stock: true).count,
          out_of_stock_products: @supplier.supplier_tire_products.where(in_stock: false).count,

          # Last sync info
          last_sync_at: @supplier.last_sync_at,
          sync_status: @supplier.sync_status,

          # Conversion stats (orders today vs yesterday)
          orders_today: orders.where('created_at >= ?', Date.current.beginning_of_day).count,
          orders_yesterday: orders.where(created_at: Date.yesterday.beginning_of_day..Date.yesterday.end_of_day).count,

          # Average order value
          average_order_value: completed_orders.any? ? (completed_orders.sum(:total_amount) / completed_orders.count).to_f.round(2) : 0
        }
      end

      def recent_orders_data
        @supplier.tire_orders
                 .where.not(status: 'draft')
                 .includes(:user, tire_order_items: :supplier_tire_product)
                 .recent
                 .limit(10)
                 .map { |order| format_order_brief(order) }
      end

      def calculate_top_products
        # Top selling products by quantity
        top_by_quantity = TireOrderItem
          .joins(:tire_order, :supplier_tire_product)
          .where(tire_orders: { supplier_id: @supplier.id, status: 'completed' })
          .group('supplier_tire_products.id', 'supplier_tire_products.name', 'supplier_tire_products.brand_normalized', 'supplier_tire_products.price_uah')
          .select('supplier_tire_products.id, supplier_tire_products.name, supplier_tire_products.brand_normalized as brand, supplier_tire_products.price_uah as price, SUM(tire_order_items.quantity) as total_sold')
          .order('total_sold DESC')
          .limit(10)

        top_by_quantity.map do |product|
          {
            id: product.id,
            name: product.name,
            brand: product.brand,
            price: product.price&.to_f,
            total_sold: product.total_sold.to_i
          }
        end
      end

      def calculate_revenue_chart
        # Revenue by day for last 30 days
        daily_revenue = @supplier.tire_orders
          .completed
          .where('created_at >= ?', 30.days.ago)
          .group("DATE(created_at)")
          .sum(:total_amount)

        # Fill missing days with zeros
        (30.days.ago.to_date..Date.current).map do |date|
          {
            date: date.strftime('%Y-%m-%d'),
            revenue: (daily_revenue[date] || 0).to_f
          }
        end
      end

      def format_order_brief(order)
        {
          id: order.id,
          status: order.status,
          status_display: order.status_display,
          client_name: order.client_name,
          items_count: order.items_count,
          total_amount: order.total_amount.to_f,
          created_at: order.created_at.strftime('%d.%m.%Y %H:%M')
        }
      end
    end
  end
end
