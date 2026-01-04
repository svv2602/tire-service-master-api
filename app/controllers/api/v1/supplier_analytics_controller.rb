module Api
  module V1
    class SupplierAnalyticsController < ApiController
      before_action :authenticate_request
      before_action :ensure_supplier_access!
      before_action :set_supplier
      before_action :set_date_range

      # GET /api/v1/suppliers/:supplier_id/analytics
      def show
        render json: {
          overview: overview_stats,
          sales_by_period: sales_by_period,
          top_products: top_selling_products,
          top_partners: top_buying_partners,
          category_breakdown: category_breakdown,
          period: {
            from: @date_from.to_s,
            to: @date_to.to_s,
            grouping: params[:grouping] || 'day'
          }
        }
      end

      # GET /api/v1/suppliers/:supplier_id/analytics/sales
      def sales
        render json: {
          sales_by_period: sales_by_period,
          period: {
            from: @date_from.to_s,
            to: @date_to.to_s,
            grouping: params[:grouping] || 'day'
          }
        }
      end

      # GET /api/v1/suppliers/:supplier_id/analytics/products
      def products
        render json: {
          top_products: top_selling_products(limit: params[:limit]&.to_i || 20),
          total_products: @supplier.supplier_tire_products.count,
          active_products: @supplier.supplier_tire_products.in_stock.count
        }
      end

      # GET /api/v1/suppliers/:supplier_id/analytics/partners
      def partners
        render json: {
          top_partners: top_buying_partners(limit: params[:limit]&.to_i || 20),
          total_partners: partners_count
        }
      end

      # GET /api/v1/suppliers/:supplier_id/analytics/categories
      def categories
        render json: {
          category_breakdown: category_breakdown,
          season_breakdown: season_breakdown
        }
      end

      # GET /api/v1/suppliers/:supplier_id/analytics/export
      def export
        format = params[:format] || 'csv'

        unless %w[csv xlsx].include?(format)
          return render json: { error: 'Неподдерживаемый формат. Используйте csv или xlsx.' }, status: :bad_request
        end

        report_service = SupplierReportService.new(@supplier, {
          date_from: params[:date_from],
          date_to: params[:date_to],
          format: format,
          report_type: params[:report_type] || 'full'
        })

        if report_service.should_run_in_background?
          # Schedule background job for large reports
          job_id = GenerateSupplierReportJob.perform_later(@supplier.id, {
            date_from: params[:date_from],
            date_to: params[:date_to],
            format: format,
            report_type: params[:report_type] || 'full'
          }).job_id

          render json: {
            success: true,
            async: true,
            job_id: job_id,
            message: 'Отчёт генерируется в фоне. Вы получите уведомление когда он будет готов.'
          }, status: :accepted
        else
          # Generate synchronously for small reports
          begin
            report_data = report_service.generate

            filename = "supplier_report_#{@supplier.firm_id}_#{Date.current.strftime('%Y%m%d')}.#{format}"

            content_type = case format
                          when 'csv' then 'text/csv; charset=utf-8'
                          when 'xlsx' then 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                          end

            send_data report_data,
                      filename: filename,
                      type: content_type,
                      disposition: 'attachment'
          rescue ArgumentError => e
            render json: { error: e.message }, status: :bad_request
          rescue StandardError => e
            Rails.logger.error "Report generation failed: #{e.message}"
            render json: { error: 'Ошибка генерации отчёта' }, status: :internal_server_error
          end
        end
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

      def set_date_range
        @date_from = params[:date_from].present? ? Date.parse(params[:date_from]) : 30.days.ago.to_date
        @date_to = params[:date_to].present? ? Date.parse(params[:date_to]) : Date.current
      rescue ArgumentError
        render json: { error: 'Неверный формат даты' }, status: :bad_request
      end

      def supplier_orders
        @supplier_orders ||= TireOrder.where(supplier_id: @supplier.id)
                                       .where(created_at: @date_from.beginning_of_day..@date_to.end_of_day)
      end

      def completed_orders
        @completed_orders ||= supplier_orders.where(status: ['delivered', 'completed'])
      end

      def overview_stats
        {
          total_orders: supplier_orders.count,
          completed_orders: completed_orders.count,
          total_revenue: completed_orders.joins(:tire_order_items).sum('tire_order_items.quantity * tire_order_items.price_at_order').to_f,
          average_order_value: calculate_average_order_value,
          total_items_sold: completed_orders.joins(:tire_order_items).sum('tire_order_items.quantity').to_i,
          unique_partners: supplier_orders.distinct.count(:partner_id),
          conversion_rate: calculate_conversion_rate
        }
      end

      def calculate_average_order_value
        return 0.0 if completed_orders.count.zero?

        total = completed_orders.joins(:tire_order_items).sum('tire_order_items.quantity * tire_order_items.price_at_order').to_f
        (total / completed_orders.count).round(2)
      end

      def calculate_conversion_rate
        return 0.0 if supplier_orders.count.zero?

        ((completed_orders.count.to_f / supplier_orders.count) * 100).round(2)
      end

      def sales_by_period
        grouping = params[:grouping] || 'day'

        orders = completed_orders.joins(:tire_order_items)
                                 .select("DATE_TRUNC('#{grouping}', tire_orders.created_at) as period,
                                          SUM(tire_order_items.quantity * tire_order_items.price_at_order) as revenue,
                                          COUNT(DISTINCT tire_orders.id) as orders_count,
                                          SUM(tire_order_items.quantity) as items_count")
                                 .group("DATE_TRUNC('#{grouping}', tire_orders.created_at)")
                                 .order("period ASC")

        orders.map do |row|
          {
            period: format_period(row.period, grouping),
            revenue: row.revenue.to_f,
            orders_count: row.orders_count,
            items_count: row.items_count
          }
        end
      end

      def format_period(date, grouping)
        return nil unless date

        case grouping
        when 'day'
          date.strftime('%Y-%m-%d')
        when 'week'
          date.strftime('%Y-W%W')
        when 'month'
          date.strftime('%Y-%m')
        else
          date.to_s
        end
      end

      def top_selling_products(limit: 10)
        TireOrderItem.joins(:tire_order)
                     .where(tire_orders: { supplier_id: @supplier.id, status: ['delivered', 'completed'] })
                     .where(tire_orders: { created_at: @date_from.beginning_of_day..@date_to.end_of_day })
                     .joins(:supplier_tire_product)
                     .select('tire_order_items.supplier_tire_product_id,
                              supplier_tire_products.original_brand as brand,
                              supplier_tire_products.original_model as model,
                              supplier_tire_products.name as product_name,
                              SUM(tire_order_items.quantity) as total_quantity,
                              SUM(tire_order_items.quantity * tire_order_items.price_at_order) as total_revenue,
                              COUNT(DISTINCT tire_order_items.tire_order_id) as orders_count')
                     .group('tire_order_items.supplier_tire_product_id,
                             supplier_tire_products.original_brand,
                             supplier_tire_products.original_model,
                             supplier_tire_products.name')
                     .order('total_quantity DESC')
                     .limit(limit)
                     .map do |item|
          {
            product_id: item.supplier_tire_product_id,
            brand: item.brand,
            model: item.model,
            name: item.product_name,
            total_quantity: item.total_quantity,
            total_revenue: item.total_revenue.to_f,
            orders_count: item.orders_count
          }
        end
      end

      def top_buying_partners(limit: 10)
        TireOrder.where(supplier_id: @supplier.id, status: ['delivered', 'completed'])
                 .where(created_at: @date_from.beginning_of_day..@date_to.end_of_day)
                 .joins(:tire_order_items)
                 .joins(:partner)
                 .select('tire_orders.partner_id,
                          partners.company_name,
                          partners.contact_person,
                          COUNT(DISTINCT tire_orders.id) as orders_count,
                          SUM(tire_order_items.quantity) as total_items,
                          SUM(tire_order_items.quantity * tire_order_items.price_at_order) as total_spent')
                 .group('tire_orders.partner_id, partners.company_name, partners.contact_person')
                 .order('total_spent DESC')
                 .limit(limit)
                 .map do |row|
          {
            partner_id: row.partner_id,
            company_name: row.company_name,
            contact_person: row.contact_person,
            orders_count: row.orders_count,
            total_items: row.total_items,
            total_spent: row.total_spent.to_f
          }
        end
      end

      def partners_count
        TireOrder.where(supplier_id: @supplier.id)
                 .where(created_at: @date_from.beginning_of_day..@date_to.end_of_day)
                 .distinct.count(:partner_id)
      end

      def category_breakdown
        TireOrderItem.joins(:tire_order)
                     .where(tire_orders: { supplier_id: @supplier.id, status: ['delivered', 'completed'] })
                     .where(tire_orders: { created_at: @date_from.beginning_of_day..@date_to.end_of_day })
                     .joins(:supplier_tire_product)
                     .select('supplier_tire_products.brand_normalized as brand,
                              SUM(tire_order_items.quantity) as total_quantity,
                              SUM(tire_order_items.quantity * tire_order_items.price_at_order) as total_revenue')
                     .group('supplier_tire_products.brand_normalized')
                     .order('total_revenue DESC')
                     .limit(20)
                     .map do |row|
          {
            brand: row.brand,
            total_quantity: row.total_quantity,
            total_revenue: row.total_revenue.to_f
          }
        end
      end

      def season_breakdown
        TireOrderItem.joins(:tire_order)
                     .where(tire_orders: { supplier_id: @supplier.id, status: ['delivered', 'completed'] })
                     .where(tire_orders: { created_at: @date_from.beginning_of_day..@date_to.end_of_day })
                     .joins(:supplier_tire_product)
                     .select('supplier_tire_products.season,
                              SUM(tire_order_items.quantity) as total_quantity,
                              SUM(tire_order_items.quantity * tire_order_items.price_at_order) as total_revenue')
                     .group('supplier_tire_products.season')
                     .order('total_revenue DESC')
                     .map do |row|
          {
            season: row.season,
            total_quantity: row.total_quantity,
            total_revenue: row.total_revenue.to_f
          }
        end
      end
    end
  end
end
