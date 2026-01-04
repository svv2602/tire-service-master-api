module Api
  module V1
    class SupplierOrdersController < ApiController
      before_action :authenticate_request
      before_action :ensure_supplier_access!
      before_action :set_supplier
      before_action :set_order, only: [:show, :update, :confirm, :start_processing, :ship, :deliver, :complete, :cancel]

      # GET /api/v1/supplier/:supplier_id/orders
      # List all orders for supplier with filters and pagination
      def index
        @orders = @supplier.tire_orders
                           .where.not(status: 'draft')
                           .includes(:user, :partner, tire_order_items: :supplier_tire_product)
                           .recent

        # Apply filters
        @orders = apply_filters(@orders)

        # Pagination
        result = paginate(@orders)

        render json: {
          orders: result[:data].map { |order| format_order(order) },
          pagination: result[:pagination],
          stats: calculate_stats
        }
      end

      # GET /api/v1/supplier/:supplier_id/orders/:id
      # Show single order details
      def show
        render json: {
          order: format_order_detailed(@order)
        }
      end

      # PATCH /api/v1/supplier/:supplier_id/orders/:id
      # Update order (notes, tracking_number)
      def update
        authorize @order, :update?, policy_class: SupplierOrderPolicy

        if @order.update(order_update_params)
          render json: {
            success: true,
            order: format_order(@order),
            message: 'Заказ обновлён'
          }
        else
          render json: {
            success: false,
            errors: @order.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/supplier/:supplier_id/orders/:id/confirm
      # Confirm order
      def confirm
        authorize @order, :confirm?, policy_class: SupplierOrderPolicy

        if @order.confirm!
          render json: {
            success: true,
            order: format_order(@order),
            message: 'Заказ подтверждён'
          }
        else
          render json: {
            success: false,
            errors: ['Невозможно подтвердить заказ в текущем статусе']
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/supplier/:supplier_id/orders/:id/start_processing
      # Start processing order
      def start_processing
        authorize @order, :start_processing?, policy_class: SupplierOrderPolicy

        if @order.start_processing!
          render json: {
            success: true,
            order: format_order(@order),
            message: 'Заказ взят в обработку'
          }
        else
          render json: {
            success: false,
            errors: ['Невозможно начать обработку заказа в текущем статусе']
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/supplier/:supplier_id/orders/:id/ship
      # Ship order with optional tracking number
      def ship
        authorize @order, :ship?, policy_class: SupplierOrderPolicy

        @order.tracking_number = params[:tracking_number] if params[:tracking_number].present?

        if @order.ship!
          render json: {
            success: true,
            order: format_order(@order),
            message: 'Заказ отправлен'
          }
        else
          render json: {
            success: false,
            errors: ['Невозможно отправить заказ в текущем статусе']
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/supplier/:supplier_id/orders/:id/deliver
      # Mark order as delivered
      def deliver
        authorize @order, :deliver?, policy_class: SupplierOrderPolicy

        if @order.deliver!
          render json: {
            success: true,
            order: format_order(@order),
            message: 'Заказ доставлен'
          }
        else
          render json: {
            success: false,
            errors: ['Невозможно отметить заказ как доставленный']
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/supplier/:supplier_id/orders/:id/complete
      # Complete order
      def complete
        authorize @order, :complete?, policy_class: SupplierOrderPolicy

        if @order.complete!
          render json: {
            success: true,
            order: format_order(@order),
            message: 'Заказ завершён'
          }
        else
          render json: {
            success: false,
            errors: ['Невозможно завершить заказ в текущем статусе']
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/supplier/:supplier_id/orders/:id/cancel
      # Cancel order
      def cancel
        authorize @order, :cancel?, policy_class: SupplierOrderPolicy

        if @order.cancel!
          render json: {
            success: true,
            order: format_order(@order),
            message: 'Заказ отменён'
          }
        else
          render json: {
            success: false,
            errors: ['Невозможно отменить заказ в текущем статусе']
          }, status: :unprocessable_entity
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

      def set_order
        @order = @supplier.tire_orders.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Заказ не найден' }, status: :not_found
      end

      def order_update_params
        params.require(:order).permit(:notes, :tracking_number)
      end

      def apply_filters(orders)
        # Filter by status
        orders = orders.by_status(params[:status]) if params[:status].present?

        # Filter by partner
        orders = orders.by_partner(params[:partner_id]) if params[:partner_id].present?

        # Filter by date range
        if params[:date_from].present?
          orders = orders.where('created_at >= ?', Date.parse(params[:date_from]).beginning_of_day)
        end
        if params[:date_to].present?
          orders = orders.where('created_at <= ?', Date.parse(params[:date_to]).end_of_day)
        end

        # Search by client name or phone
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          orders = orders.where(
            'client_name ILIKE ? OR client_phone ILIKE ? OR tracking_number ILIKE ?',
            search_term, search_term, search_term
          )
        end

        orders
      end

      def calculate_stats
        base = @supplier.tire_orders.where.not(status: 'draft')
        {
          total: base.count,
          pending: base.pending.count,
          confirmed: base.confirmed.count,
          processing: base.processing.count,
          shipped: base.shipped.count,
          delivered: base.delivered.count,
          completed: base.completed.count,
          cancelled: base.cancelled.count,
          total_revenue: base.completed.sum(:total_amount)
        }
      end

      def format_order(order)
        {
          id: order.id,
          status: order.status,
          status_display: order.status_display,
          client_name: order.client_name,
          client_phone: order.client_phone,
          items_count: order.items_count,
          total_amount: order.total_amount.to_f,
          formatted_total: order.formatted_total,
          tracking_number: order.tracking_number,
          shipped_at: order.shipped_at&.strftime('%d.%m.%Y %H:%M'),
          delivered_at: order.delivered_at&.strftime('%d.%m.%Y %H:%M'),
          notes: order.notes,
          partner: format_partner(order.ordering_partner),
          available_actions: order.available_events.map(&:to_s),
          created_at: order.created_at.strftime('%d.%m.%Y %H:%M'),
          updated_at: order.updated_at.strftime('%d.%m.%Y %H:%M')
        }
      end

      def format_order_detailed(order)
        format_order(order).merge(
          items: order.tire_order_items.includes(:supplier_tire_product).map { |item| format_order_item(item) },
          user: format_user(order.user),
          comment: order.comment,
          delivery_days: order.delivery_days
        )
      end

      def format_order_item(item)
        product = item.supplier_tire_product
        {
          id: item.id,
          quantity: item.quantity,
          price_at_order: item.price_at_order.to_f,
          total_price: item.total_price.to_f,
          product: {
            id: product.id,
            name: product.name,
            brand: product.brand_normalized,
            model: product.original_model,
            size: product.tire_size,
            season: product.season,
            image_url: product.image_url,
            current_price: product.price_uah&.to_f,
            in_stock: product.in_stock
          }
        }
      end

      def format_partner(partner)
        return nil unless partner

        {
          id: partner.id,
          name: partner.company_name,
          contact_person: partner.contact_person
        }
      end

      def format_user(user)
        return nil unless user

        {
          id: user.id,
          full_name: user.full_name,
          email: user.email,
          phone: user.phone
        }
      end
    end
  end
end
