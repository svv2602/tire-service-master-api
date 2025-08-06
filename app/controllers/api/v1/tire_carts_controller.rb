class Api::V1::TireCartsController < ApplicationController
  before_action :authenticate_request!
  before_action :set_cart, only: [:show, :destroy, :add_item, :update_item, :remove_item, :clear]
  before_action :set_cart_item, only: [:update_item, :remove_item]

  # GET /api/v1/tire_carts
  # Получение всех корзин пользователя (по поставщикам)
  def index
    @carts = current_user.tire_orders.draft.includes(:supplier, tire_order_items: :supplier_tire_product)
    
    render json: {
      carts: @carts.map { |cart| format_cart(cart) },
      total_carts: @carts.count,
      total_items: @carts.sum(&:items_count)
    }
  end

  # GET /api/v1/tire_carts/:id
  # Получение конкретной корзины
  def show
    render json: { cart: format_cart_detailed(@cart) }
  end

  # POST /api/v1/tire_carts/:id/items
  # Добавление товара в корзину
  def add_item
    @product = SupplierTireProduct.find(params[:supplier_tire_product_id])
    
    # Проверяем, что товар в наличии
    unless @product.in_stock
      return render json: { 
        error: 'Товар временно недоступен' 
      }, status: :unprocessable_entity
    end

    # Проверяем, есть ли уже такой товар в корзине
    existing_item = @cart.tire_order_items.find_by(supplier_tire_product: @product)
    
    if existing_item
      # Увеличиваем количество
      new_quantity = existing_item.quantity + (params[:quantity]&.to_i || 1)
      existing_item.update!(quantity: new_quantity)
      @item = existing_item
    else
      # Создаем новый элемент корзины
      @item = @cart.tire_order_items.build(
        supplier_tire_product: @product,
        quantity: params[:quantity]&.to_i || 1
      )
      
      unless @item.save
        return render json: { 
          errors: @item.errors.full_messages 
        }, status: :unprocessable_entity
      end
    end

    render json: { 
      message: 'Товар добавлен в корзину',
      item: format_cart_item(@item),
      cart: format_cart(@cart.reload)
    }, status: :created

  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Товар не найден' }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PUT /api/v1/tire_carts/:id/items/:item_id
  # Изменение количества товара в корзине
  def update_item
    @cart_item.update!(quantity: params[:quantity].to_i)
    
    render json: {
      message: 'Количество товара обновлено',
      item: format_cart_item(@cart_item),
      cart: format_cart(@cart.reload)
    }

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # DELETE /api/v1/tire_carts/:id/items/:item_id
  # Удаление товара из корзины
  def remove_item
    @cart_item.destroy!
    
    render json: {
      message: 'Товар удален из корзины',
      cart: format_cart(@cart.reload)
    }
  end

  # DELETE /api/v1/tire_carts/:id
  # Очистка корзины
  def clear
    @cart.tire_order_items.destroy_all
    
    render json: {
      message: 'Корзина очищена',
      cart: format_cart(@cart.reload)
    }
  end

  # DELETE /api/v1/tire_carts/:id
  # Удаление корзины
  def destroy
    @cart.destroy
    
    render json: {
      message: 'Корзина удалена'
    }
  end

  private

  def set_cart
    # Находим или создаем корзину для конкретного поставщика
    supplier_id = params[:supplier_id] || params[:id]
    
    @cart = current_user.tire_orders.draft.find_by(supplier_id: supplier_id)
    
    # Если корзины нет и это запрос на добавление товара, создаем новую
    if @cart.nil? && action_name == 'add_item'
      @product = SupplierTireProduct.find(params[:supplier_tire_product_id])
      @cart = current_user.tire_orders.create!(
        supplier: @product.supplier,
        status: 'draft',
        client_name: current_user.full_name || '',
        client_phone: current_user.phone || '',
        total_amount: 0
      )
    end
    
    unless @cart
      render json: { error: 'Корзина не найдена' }, status: :not_found
    end
  end

  def set_cart_item
    @cart_item = @cart.tire_order_items.find(params[:item_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Товар в корзине не найден' }, status: :not_found
  end

  def format_cart(cart)
    {
      id: cart.id,
      supplier: {
        id: cart.supplier.id,
        name: cart.supplier.name,
        firm_id: cart.supplier.firm_id
      },
      items_count: cart.items_count,
      total_amount: cart.total_amount.to_f,
      formatted_total: cart.formatted_total,
      updated_at: cart.updated_at.strftime('%d.%m.%Y %H:%M')
    }
  end

  def format_cart_detailed(cart)
    {
      id: cart.id,
      supplier: {
        id: cart.supplier.id,
        name: cart.supplier.name,
        firm_id: cart.supplier.firm_id
      },
      items: cart.tire_order_items.includes(:supplier_tire_product).map { |item| format_cart_item(item) },
      items_count: cart.items_count,
      total_amount: cart.total_amount.to_f,
      formatted_total: cart.formatted_total,
      client_name: cart.client_name,
      client_phone: cart.client_phone,
      comment: cart.comment,
      created_at: cart.created_at.strftime('%d.%m.%Y %H:%M'),
      updated_at: cart.updated_at.strftime('%d.%m.%Y %H:%M')
    }
  end

  def format_cart_item(item)
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
        in_stock: product.in_stock,
        stock_status: product.stock_status,
        current_price: product.price_uah&.to_f
      },
      available: item.product_available?,
      availability_message: item.product_availability_message
    }
  end
end