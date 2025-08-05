class Api::V1::TireOrdersController < ApplicationController
  before_action :authenticate_request!
  before_action :set_order, only: [:show, :update, :cancel, :archive]
  before_action :ensure_admin!, only: [:index_all, :confirm, :start_processing, :complete, :admin_cancel]

  # GET /api/v1/tire_orders
  # Получение заказов текущего пользователя
  def index
    @orders = current_user.tire_orders
                         .where.not(status: 'draft')
                         .includes(:supplier, tire_order_items: :supplier_tire_product)
                         .recent
    
    # Фильтрация по статусу
    @orders = @orders.by_status(params[:status]) if params[:status].present?
    
    # Пагинация
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 20, 100].min
    
    @orders = @orders.limit(per_page).offset((page - 1) * per_page)
    total_count = current_user.tire_orders.where.not(status: 'draft').count
    
    render json: {
      orders: @orders.map { |order| format_order(order) },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # GET /api/v1/tire_orders/all (только для админов)
  # Получение всех заказов
  def index_all
    @orders = TireOrder.where.not(status: 'draft')
                      .includes(:user, :supplier, tire_order_items: :supplier_tire_product)
                      .recent
    
    # Фильтрация
    @orders = @orders.by_status(params[:status]) if params[:status].present?
    @orders = @orders.by_supplier(params[:supplier_id]) if params[:supplier_id].present?
    
    # Поиск по клиенту
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @orders = @orders.joins(:user).where(
        'users.first_name ILIKE ? OR users.last_name ILIKE ? OR tire_orders.client_name ILIKE ? OR tire_orders.client_phone ILIKE ?',
        search_term, search_term, search_term, search_term
      )
    end
    
    # Пагинация
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || 20, 100].min
    
    total_count = @orders.count
    @orders = @orders.limit(per_page).offset((page - 1) * per_page)
    
    render json: {
      orders: @orders.map { |order| format_order_detailed(order) },
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # GET /api/v1/tire_orders/:id
  # Получение конкретного заказа
  def show
    authorize_order_access!
    render json: { order: format_order_detailed(@order) }
  end

  # POST /api/v1/tire_orders
  # Создание заказов из корзин (отправка заказов)
  def create
    carts = current_user.tire_orders.draft.includes(:tire_order_items)
    
    if carts.empty?
      return render json: { error: 'Нет товаров в корзине для заказа' }, status: :unprocessable_entity
    end

    created_orders = []
    
    ActiveRecord::Base.transaction do
      carts.each do |cart|
        # Проверяем, что в корзине есть товары
        if cart.tire_order_items.empty?
          cart.destroy
          next
        end

        # Проверяем доступность всех товаров
        unavailable_items = cart.tire_order_items.joins(:supplier_tire_product)
                                .where(supplier_tire_products: { in_stock: false })
        
        if unavailable_items.exists?
          unavailable_names = unavailable_items.joins(:supplier_tire_product)
                                             .pluck('supplier_tire_products.name')
          raise ActiveRecord::Rollback, "Товары недоступны: #{unavailable_names.join(', ')}"
        end

        # Обновляем контактную информацию из параметров
        cart.update!(
          client_name: params[:client_name] || cart.client_name,
          client_phone: params[:client_phone] || cart.client_phone,
          comment: params[:comment] || cart.comment
        )

        # Отправляем заказ
        if cart.submit!
          created_orders << cart
        else
          raise ActiveRecord::Rollback, cart.errors.full_messages.join(', ')
        end
      end
    end

    if created_orders.any?
      render json: {
        message: "Создано заказов: #{created_orders.count}",
        orders: created_orders.map { |order| format_order(order) }
      }, status: :created
    else
      render json: { error: 'Не удалось создать заказы' }, status: :unprocessable_entity
    end

  rescue ActiveRecord::Rollback => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /api/v1/tire_orders/:id/confirm (только админы)
  def confirm
    if @order.confirm!
      render json: { 
        message: 'Заказ подтвержден', 
        order: format_order(@order) 
      }
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/tire_orders/:id/start_processing (только админы)
  def start_processing
    if @order.start_processing!
      render json: { 
        message: 'Заказ взят в обработку', 
        order: format_order(@order) 
      }
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/tire_orders/:id/complete (только админы)
  def complete
    if @order.complete!
      render json: { 
        message: 'Заказ выполнен', 
        order: format_order(@order) 
      }
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/tire_orders/:id/cancel
  def cancel
    authorize_cancel_access!
    
    if @order.cancel!
      render json: { 
        message: 'Заказ отменен', 
        order: format_order(@order) 
      }
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/tire_orders/:id/archive
  def archive
    authorize_order_access!
    
    if @order.archive!
      render json: { 
        message: 'Заказ перемещен в архив', 
        order: format_order(@order) 
      }
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_order
    @order = TireOrder.includes(:supplier, :user, tire_order_items: :supplier_tire_product)
                     .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Заказ не найден' }, status: :not_found
  end

  def authorize_order_access!
    unless current_user.admin? || @order.user == current_user
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end

  def authorize_cancel_access!
    can_cancel = if current_user.admin?
                   @order.can_be_cancelled_by_admin?
                 else
                   @order.user == current_user && @order.can_be_cancelled_by_user?
                 end
    
    unless can_cancel
      render json: { error: 'Отмена заказа недоступна' }, status: :forbidden
    end
  end

  def format_order(order)
    {
      id: order.id,
      status: order.status,
      status_display: order.status_display,
      supplier: {
        id: order.supplier.id,
        name: order.supplier.name,
        firm_id: order.supplier.firm_id
      },
      items_count: order.items_count,
      total_amount: order.total_amount.to_f,
      formatted_total: order.formatted_total,
      client_name: order.client_name,
      client_phone: order.client_phone,
      comment: order.comment,
      created_at: order.created_at.strftime('%d.%m.%Y %H:%M'),
      updated_at: order.updated_at.strftime('%d.%m.%Y %H:%M')
    }
  end

  def format_order_detailed(order)
    base_format = format_order(order)
    base_format.merge({
      user: {
        id: order.user.id,
        full_name: order.user.full_name,
        email: order.user.email,
        phone: order.user.phone
      },
      items: order.tire_order_items.map { |item| format_order_item(item) },
      can_be_cancelled: current_user.admin? ? 
                       order.can_be_cancelled_by_admin? : 
                       order.can_be_cancelled_by_user?,
      can_be_archived: order.can_be_archived?
    })
  end

  def format_order_item(item)
    product = item.supplier_tire_product
    
    {
      id: item.id,
      quantity: item.quantity,
      price_at_order: item.price_at_order.to_f,
      total_price: item.total_price.to_f,
      formatted_price: item.formatted_price_at_order,
      formatted_total: item.formatted_total_price,
      product: {
        id: product.id,
        name: product.name,
        brand: product.brand,
        model: product.model,
        size: product.tire_size,
        season: product.season,
        image_url: product.image_url,
        product_url: product.product_url,
        current_price: product.price_uah&.to_f
      },
      available: item.product_available?,
      availability_message: item.product_availability_message
    }
  end
end