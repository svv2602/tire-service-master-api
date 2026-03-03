module Api
  module V1
    class PartnerOrdersController < ApiController
      skip_after_action :verify_authorized
      before_action :ensure_partner_access
      before_action :set_partner
      before_action :set_order, only: [:show, :mark_as_ready, :mark_as_delivered, :cancel, :add_note]
      
      # GET /api/v1/partners/:partner_id/orders
      def index
        orders_scope = apply_filters(base_orders_scope)
        orders_scope = orders_scope.includes(:order_items, :supplier, service_point: :city)
                                  .order(created_at: :desc)
        
        paginated_data = paginate(orders_scope)
        
        render json: {
          orders: paginated_data[:data].map { |order| OrderSerializer.new(order).as_json },
          pagination: paginated_data[:pagination],
          stats: partner_orders_stats
        }
      end
      
      # GET /api/v1/partners/:partner_id/orders/:id
      def show
        render json: OrderSerializer.new(@order, include: [:order_items, :service_point]).serializable_hash
      end
      
      # POST /api/v1/partners/:partner_id/orders/:id/mark_as_ready
      def mark_as_ready
        if @order.can_mark_as_ready?
          @order.update!(
            status: 'ready',
            ready_at: Time.current,
            processed_at: Time.current
          )

          # Логирование действия партнера
          Rails.logger.info "Партнер #{@partner.company_name} отметил заказ #{@order.ttn} как готовый"

          # Отправка SMS клиенту о готовности заказа
          send_order_ready_sms(@order)

          render json: OrderSerializer.new(@order).serializable_hash
        else
          render json: {
            error: "Нельзя отметить заказ как готовый в текущем статусе: #{@order.status_label}"
          }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/partners/:partner_id/orders/:id/mark_as_delivered
      def mark_as_delivered
        if @order.can_mark_as_delivered?
          @order.update!(
            status: 'delivered', 
            delivered_at: Time.current
          )
          
          # Логирование действия партнера
          Rails.logger.info "Партнер #{@partner.company_name} отметил заказ #{@order.ttn} как выданный"
          
          render json: OrderSerializer.new(@order).serializable_hash
        else
          render json: { 
            error: "Нельзя отметить заказ как выданный в текущем статусе: #{@order.status_label}" 
          }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/partners/:partner_id/orders/:id/cancel
      def cancel
        if @order.can_cancel?
          @order.update!(
            status: 'canceled', 
            canceled_at: Time.current,
            cancellation_reason: params[:reason] || 'Отменен партнером'
          )
          
          # Логирование действия партнера
          Rails.logger.info "Партнер #{@partner.company_name} отменил заказ #{@order.ttn}"
          
          render json: OrderSerializer.new(@order).serializable_hash
        else
          render json: { 
            error: "Нельзя отменить заказ в текущем статусе: #{@order.status_label}" 
          }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/partners/:partner_id/orders/:id/add_note
      def add_note
        if @order.update(notes: params[:note])
          Rails.logger.info "Партнер #{@partner.company_name} добавил заметку к заказу #{@order.ttn}"
          render json: OrderSerializer.new(@order).serializable_hash
        else
          render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/partners/:partner_id/orders/stats
      def stats
        render json: detailed_partner_stats
      end
      
      # GET /api/v1/partners/:partner_id/orders/export
      def export
        orders = apply_filters(base_orders_scope)
        
        # Генерация CSV
        csv_data = generate_csv_export(orders)
        
        send_data csv_data,
                  filename: "orders_#{@partner.company_name}_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv',
                  disposition: 'attachment'
      end
      
      private
      
      def ensure_partner_access
        unless current_user&.partner? || current_user&.admin?
          render json: { error: 'Доступ запрещен' }, status: :forbidden
        end
      end
      
      def set_partner
        if current_user.admin?
          @partner = Partner.find(params[:partner_id])
        else
          @partner = current_user.partner
          # Проверяем, что партнер пытается получить доступ только к своим данным
          if params[:partner_id].to_i != @partner.id
            render json: { error: 'Доступ запрещен' }, status: :forbidden
            return
          end
        end
      end
      
      def set_order
        @order = base_orders_scope.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Заказ не найден' }, status: :not_found
      end
      
      def base_orders_scope
        @partner.orders
      end
      
      def apply_filters(scope)
        scope = scope.by_status(params[:status]) if params[:status].present?
        scope = scope.by_date_range(params[:from_date], params[:to_date]) if params[:from_date] && params[:to_date]
        scope = scope.search_by_ttn(params[:ttn]) if params[:ttn].present?
        scope = scope.search_by_customer(params[:customer]) if params[:customer].present?
        scope = scope.by_customer_phone(params[:phone]) if params[:phone].present?
        scope = scope.by_service_point(params[:service_point_id]) if params[:service_point_id].present?
        scope
      end
      
      def partner_orders_stats
        orders = @partner.orders
        {
          total_orders: orders.count,
          active_orders: orders.where.not(status: ['delivered', 'canceled']).count,
          ready_orders: orders.where(status: 'ready').count,
          delivered_orders: orders.where(status: 'delivered').count,
          canceled_orders: orders.where(status: 'canceled').count,
          total_revenue: orders.where(status: 'delivered').sum(:total_amount),
          today_orders: orders.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count
        }
      end
      
      def detailed_partner_stats
        orders = @partner.orders
        service_points = @partner.service_points
        
        # Статистика по периодам
        today = Date.current
        week_ago = 7.days.ago
        month_ago = 30.days.ago
        
        {
          overview: {
            total_orders: orders.count,
            total_revenue: orders.where(status: 'delivered').sum(:total_amount),
            active_service_points: service_points.where(is_active: true).count,
            total_service_points: service_points.count
          },
          status_breakdown: orders.group(:status).count,
          period_stats: {
            today: orders.where(created_at: today.beginning_of_day..today.end_of_day).count,
            week: orders.where(created_at: week_ago..Time.current).count,
            month: orders.where(created_at: month_ago..Time.current).count
          },
          service_points_stats: service_points.map do |sp|
            sp_orders = orders.where(service_point: sp)
            {
              id: sp.id,
              name: sp.name,
              city: sp.city.name,
              total_orders: sp_orders.count,
              active_orders: sp_orders.where.not(status: ['delivered', 'canceled']).count,
              revenue: sp_orders.where(status: 'delivered').sum(:total_amount)
            }
          end,
          recent_orders: orders.order(created_at: :desc).limit(10).map do |order|
            {
              id: order.id,
              ttn: order.ttn,
              customer_name: order.customer_name,
              status: order.status,
              status_label: order.status_label,
              total_amount: order.total_amount,
              service_point_name: order.service_point.name,
              created_at: order.created_at
            }
          end
        }
      end
      
      def generate_csv_export(orders)
        require 'csv'

        CSV.generate(headers: true) do |csv|
          csv << [
            'ТТН', 'Номер заказа', 'Статус', 'Клиент', 'Телефон',
            'Сервисная точка', 'Количество товаров', 'Сумма', 'Дата создания', 'Дата выдачи'
          ]

          orders.includes(:service_point).each do |order|
            csv << [
              order.ttn,
              order.number,
              order.status_label,
              order.customer_name,
              order.customer_phone,
              order.service_point.name,
              order.total_quantity,
              order.total_amount,
              order.order_date.strftime('%d.%m.%Y %H:%M'),
              order.delivered_at&.strftime('%d.%m.%Y %H:%M')
            ]
          end
        end
      end

      def send_order_ready_sms(order)
        return unless order.customer_phone.present?

        SmsService.send_order_ready(order.customer_phone, order)
        Rails.logger.info "SMS отправлено клиенту #{order.customer_name} о готовности заказа #{order.ttn}"
      rescue StandardError => e
        Rails.logger.error "Ошибка отправки SMS о готовности заказа #{order.ttn}: #{e.message}"
      end
    end
  end
end 