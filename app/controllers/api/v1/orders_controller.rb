module Api
  module V1
    class OrdersController < ApiController
      before_action :set_order, only: [:show, :update, :destroy, :mark_as_ready, :mark_as_delivered, :cancel]
      before_action :set_service_point, only: [:index, :create]
      
      # GET /api/v1/orders
      # GET /api/v1/service_points/:service_point_id/orders
      def index
        authorize Order
        
        @orders = apply_filters(policy_scope(Order))
        @orders = @orders.includes(:order_items, :service_point)
                         .order(created_at: :desc)
                         .page(params[:page] || 1)
                         .per(params[:per_page] || 20)
        
        render json: {
          orders: OrderSerializer.new(@orders).serializable_hash[:data],
          meta: pagination_meta(@orders)
        }
      end
      
      # GET /api/v1/orders/:id
      def show
        authorize @order
        render json: OrderSerializer.new(@order, include: [:order_items]).serializable_hash
      end
      
      # POST /api/v1/orders
      # Создание заказа из JSON данных интернет-магазина
      def create
        ActiveRecord::Base.transaction do
          @order = create_order_from_json(order_params)
          
          if @order.save
            render json: OrderSerializer.new(@order, include: [:order_items]).serializable_hash, 
                   status: :created
          else
            render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
          end
        end
      rescue => e
        Rails.logger.error "Ошибка создания заказа: #{e.message}"
        render json: { error: "Ошибка создания заказа: #{e.message}" }, status: :internal_server_error
      end
      
      # PATCH /api/v1/orders/:id
      def update
        if @order.update(order_update_params)
          render json: OrderSerializer.new(@order).serializable_hash
        else
          render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/orders/:id
      def destroy
        @order.destroy
        head :no_content
      end
      
      # POST /api/v1/orders/:id/mark_as_ready
      def mark_as_ready
        authorize @order, :mark_as_ready?
        
        if @order.can_mark_as_ready?
          @order.update!(status: 'ready', ready_at: Time.current)
          render json: OrderSerializer.new(@order).serializable_hash
        else
          render json: { error: "Нельзя отметить заказ как готовый в текущем статусе" }, 
                 status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/orders/:id/mark_as_delivered
      def mark_as_delivered
        authorize @order, :mark_as_delivered?
        
        if @order.can_mark_as_delivered?
          @order.update!(status: 'delivered', delivered_at: Time.current)
          render json: OrderSerializer.new(@order).serializable_hash
        else
          render json: { error: "Нельзя отметить заказ как выданный в текущем статусе" }, 
                 status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/orders/:id/cancel
      def cancel
        authorize @order, :cancel?
        
        if @order.can_cancel?
          @order.update!(
            status: 'canceled', 
            canceled_at: Time.current,
            cancellation_reason: params[:reason]
          )
          render json: OrderSerializer.new(@order).serializable_hash
        else
          render json: { error: "Нельзя отменить заказ в текущем статусе" }, 
                 status: :unprocessable_entity
        end
      end
      
      private
      
      def set_order
        @order = Order.find(params[:id])
      end
      
      def set_service_point
        @service_point = ServicePoint.find(params[:service_point_id]) if params[:service_point_id]
      end
      
      def base_orders_scope
        scope = @service_point ? @service_point.orders : Order.all
        
        # Операторы видят только заказы своих сервисных точек
        if current_user&.operator?
          operator_service_point_ids = current_user.operator_service_points
                                                  .where(is_active: true)
                                                  .pluck(:service_point_id)
          scope = scope.where(service_point_id: operator_service_point_ids)
        end
        
        # Партнеры видят только заказы своих сервисных точек
        if current_user&.partner?
          partner = current_user.partner
          if partner
            partner_service_point_ids = partner.service_points.pluck(:id)
            scope = scope.where(service_point_id: partner_service_point_ids)
          else
            # Если партнер не найден, возвращаем пустую коллекцию
            scope = scope.none
          end
        end
        
        scope
      end
      
      def apply_filters(scope)
        scope = scope.by_status(params[:status]) if params[:status].present?
        scope = scope.by_date_range(params[:from_date], params[:to_date]) if params[:from_date] && params[:to_date]
        scope = scope.search_by_ttn(params[:ttn]) if params[:ttn].present?
        scope = scope.search_by_customer(params[:customer]) if params[:customer].present?
        scope = scope.by_customer_phone(params[:phone]) if params[:phone].present?
        scope
      end
      
      def create_order_from_json(data)
        # Обработка JSON данных от интернет-магазина
        order_data = data.is_a?(Array) ? data.first : data
        
        # Поиск сервисной точки по point_id или использование переданной
        service_point = if @service_point
          @service_point
        else
          ServicePoint.find_by(id: order_data[:point_id]) ||
          ServicePoint.joins(:partner).find_by(partners: { external_id: order_data[:point_id] })
        end
        
        raise "Сервисная точка не найдена" unless service_point
        
        # Создание заказа
        order = Order.new(
          service_point: service_point,
          status: 'received',
          order_date: parse_order_date(order_data[:date]),
          ttn: order_data[:ttn],
          number: order_data[:number],
          customer_name: order_data[:klient],
          customer_phone: order_data[:phone],
          status_kod: order_data[:status_kod],
          bas_id: order_data[:bas_id],
          separate: order_data[:separate] || 1,
          point_name: order_data[:point],
          point_id: order_data[:point_id],
          third_party_point: order_data[:third_party_point] == "Да",
          ttn_status: order_data[:ttn_status],
          ttn_status_kod: order_data[:ttn_status_kod]
        )
        
        # Добавление товаров
        if order_data[:goods].present?
          order_data[:goods].each do |good|
            order.order_items.build(
              artikul: good[:artikul],
              quantity: good[:quantity],
              price: good[:price],
              sum: good[:sum],
              bas_id: good[:bas_id]
            )
          end
        end
        
        order
      end
      
      def parse_order_date(date_string)
        # Парсинг даты в формате "29.05.2025 13:27:43"
        DateTime.strptime(date_string, "%d.%m.%Y %H:%M:%S")
      rescue ArgumentError
        DateTime.current
      end
      
      def order_params
        params.require(:order).permit(
          :status, :ttn, :number, :customer_name, :customer_phone,
          :point_name, :point_id, :third_party_point, :status_kod,
          :bas_id, :separate, :ttn_status, :ttn_status_kod, :date,
          goods: [:artikul, :quantity, :price, :sum, :bas_id]
        )
      end
      
      def order_update_params
        params.require(:order).permit(:notes, :cancellation_reason)
      end
      
      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          per_page: collection.limit_value,
          total_pages: collection.total_pages,
          total_count: collection.total_count
        }
      end
    end
  end
end 