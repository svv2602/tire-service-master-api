module Api
  module V1
    class SupplierClientsController < ApiController
      before_action :authenticate_request
      before_action :ensure_supplier_access!
      before_action :set_supplier
      before_action :set_client, only: [:show]

      # GET /api/v1/suppliers/:supplier_id/clients
      def index
        clients = partner_clients

        # Sorting
        clients = apply_sorting(clients)

        # Pagination
        page = (params[:page] || 1).to_i
        per_page = [(params[:per_page] || 20).to_i, 100].min

        total_count = clients.length
        paginated = clients.drop((page - 1) * per_page).take(per_page)

        render json: {
          clients: paginated,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count
          },
          stats: {
            total_clients: total_count,
            total_revenue: paginated.sum { |c| c[:total_spent] }
          }
        }
      end

      # GET /api/v1/suppliers/:supplier_id/clients/:id
      def show
        render json: {
          client: client_details(@client),
          orders: client_orders(@client),
          stats: client_stats(@client)
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

      def set_client
        @client = Partner.find_by(id: params[:id])

        unless @client && partner_has_ordered?(@client)
          render json: { error: 'Клиент не найден' }, status: :not_found
        end
      end

      def partner_has_ordered?(partner)
        TireOrder.where(supplier_id: @supplier.id, partner_id: partner.id).exists?
      end

      def partner_clients
        TireOrder.where(supplier_id: @supplier.id)
                 .joins(partner: :user)
                 .joins(:tire_order_items)
                 .select('tire_orders.partner_id,
                          partners.company_name,
                          partners.contact_person,
                          users.email,
                          users.phone,
                          COUNT(DISTINCT tire_orders.id) as orders_count,
                          SUM(tire_order_items.quantity) as total_items,
                          SUM(tire_order_items.quantity * tire_order_items.price_at_order) as total_spent,
                          MAX(tire_orders.created_at) as last_order_at')
                 .group('tire_orders.partner_id, partners.company_name, partners.contact_person, users.email, users.phone')
                 .map do |row|
          {
            id: row.partner_id,
            company_name: row.company_name,
            contact_person: row.contact_person,
            email: row.email,
            phone: row.phone,
            orders_count: row.orders_count,
            total_items: row.total_items.to_i,
            total_spent: row.total_spent.to_f,
            last_order_at: row.last_order_at&.strftime('%Y-%m-%d %H:%M')
          }
        end
      end

      def apply_sorting(clients)
        case params[:sort]
        when 'orders_count_asc'
          clients.sort_by { |c| c[:orders_count] }
        when 'orders_count_desc'
          clients.sort_by { |c| -c[:orders_count] }
        when 'total_spent_asc'
          clients.sort_by { |c| c[:total_spent] }
        when 'total_spent_desc'
          clients.sort_by { |c| -c[:total_spent] }
        when 'last_order_asc'
          clients.sort_by { |c| c[:last_order_at] || '' }
        when 'last_order_desc'
          clients.sort_by { |c| c[:last_order_at] || '' }.reverse
        when 'company_name'
          clients.sort_by { |c| c[:company_name]&.downcase || '' }
        else
          clients.sort_by { |c| -c[:total_spent] } # Default: by total spent desc
        end
      end

      def client_details(partner)
        {
          id: partner.id,
          company_name: partner.company_name,
          contact_person: partner.contact_person,
          email: partner.user&.email,
          phone: partner.user&.phone,
          address: partner.legal_address,
          website: partner.website,
          created_at: partner.created_at&.strftime('%Y-%m-%d')
        }
      end

      def client_orders(partner)
        TireOrder.where(supplier_id: @supplier.id, partner_id: partner.id)
                 .includes(:tire_order_items)
                 .order(created_at: :desc)
                 .limit(50)
                 .map do |order|
          {
            id: order.id,
            order_number: "ORD-#{order.id}",
            status: order.status,
            items_count: order.tire_order_items.sum(&:quantity),
            total: order.tire_order_items.sum { |i| i.quantity * i.price_at_order }.to_f,
            created_at: order.created_at&.strftime('%Y-%m-%d %H:%M'),
            delivered_at: order.delivered_at&.strftime('%Y-%m-%d %H:%M')
          }
        end
      end

      def client_stats(partner)
        orders = TireOrder.where(supplier_id: @supplier.id, partner_id: partner.id)
        completed = orders.where(status: ['delivered', 'completed'])

        {
          total_orders: orders.count,
          completed_orders: completed.count,
          cancelled_orders: orders.where(status: 'cancelled').count,
          total_spent: completed.joins(:tire_order_items)
                                .sum('tire_order_items.quantity * tire_order_items.price_at_order').to_f,
          total_items: completed.joins(:tire_order_items)
                                .sum('tire_order_items.quantity').to_i,
          first_order_at: orders.minimum(:created_at)&.strftime('%Y-%m-%d'),
          last_order_at: orders.maximum(:created_at)&.strftime('%Y-%m-%d'),
          average_order_value: calculate_average_order_value(completed)
        }
      end

      def calculate_average_order_value(orders)
        return 0.0 if orders.count.zero?

        total = orders.joins(:tire_order_items)
                      .sum('tire_order_items.quantity * tire_order_items.price_at_order').to_f
        (total / orders.count).round(2)
      end
    end
  end
end
