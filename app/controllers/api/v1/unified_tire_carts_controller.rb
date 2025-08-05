class Api::V1::UnifiedTireCartsController < ApplicationController
  skip_before_action :authenticate_request  # Отключаем обязательную аутентификацию
  before_action :optional_authenticate_request
  before_action :set_cart, only: [:show, :add_item, :update_item, :remove_item, :clear]
  before_action :set_cart_item, only: [:update_item, :remove_item]

  # GET /api/v1/unified_tire_cart
  # Получение единой корзины пользователя с группировкой по поставщикам
  def show
    render json: {
      cart: format_unified_cart(@cart),
      suppliers_summary: format_suppliers_summary(@cart)
    }
  end

  # POST /api/v1/unified_tire_cart/add_item
  # Добавление товара в единую корзину
  def add_item
    @product = SupplierTireProduct.find(params[:supplier_tire_product_id])

    # Проверяем, что товар в наличии
    unless @product.in_stock
      return render json: { 
        error: 'Товар временно недоступен' 
      }, status: :unprocessable_entity
    end

    quantity = params[:quantity]&.to_i || 1

    begin
      @cart.add_product(@product, quantity)
      
      render json: { 
        message: 'Товар добавлен в корзину',
        cart: format_unified_cart(@cart.reload),
        suppliers_summary: format_suppliers_summary(@cart)
      }, status: :created

    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end

  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Товар не найден' }, status: :not_found
  end

  # PUT /api/v1/unified_tire_cart/update_item/:item_id
  # Изменение количества товара в корзине
  def update_item
    quantity = params[:quantity].to_i
    
    if quantity <= 0
      @cart_item.destroy!
      message = 'Товар удален из корзины'
    else
      @cart_item.update!(quantity: quantity)
      message = 'Количество товара обновлено'
    end
    
    render json: {
      message: message,
      cart: format_unified_cart(@cart.reload),
      suppliers_summary: format_suppliers_summary(@cart)
    }

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # DELETE /api/v1/unified_tire_cart/remove_item/:item_id
  # Удаление товара из корзины
  def remove_item
    @cart_item.destroy!
    
    render json: {
      message: 'Товар удален из корзины',
      cart: format_unified_cart(@cart.reload),
      suppliers_summary: format_suppliers_summary(@cart)
    }
  end

  # DELETE /api/v1/unified_tire_cart/clear
  # Очистка всей корзины
  def clear
    @cart.clear!
    
    render json: {
      message: 'Корзина очищена',
      cart: format_unified_cart(@cart.reload),
      suppliers_summary: format_suppliers_summary(@cart)
    }
  end

  # POST /api/v1/unified_tire_cart/create_orders
  # Создание заказов для каждого поставщика
  def create_orders
    client_name = params[:client_name]
    client_phone = params[:client_phone]
    comments_by_supplier = params[:comments_by_supplier] || {}

    unless client_name.present? && client_phone.present?
      return render json: { 
        error: 'Необходимо указать имя и телефон клиента' 
      }, status: :unprocessable_entity
    end

    if @cart.empty?
      return render json: { 
        error: 'Корзина пуста' 
      }, status: :unprocessable_entity
    end

    begin
      created_orders = @cart.create_orders!(
        client_name: client_name,
        client_phone: client_phone,
        comments_by_supplier: comments_by_supplier
      )

      render json: {
        message: "Создано заказов: #{created_orders.length}",
        orders: created_orders.map { |order| format_order(order) },
        cart: format_unified_cart(@cart.reload)
      }, status: :created

    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Опциональная аутентификация - не требует обязательного входа
  def optional_authenticate_request
    # Пытаемся получить токен из cookies или заголовка
    access_token = cookies[:access_token]
    access_token = request.headers['Authorization']&.split(' ')&.last if access_token.nil?
    
    if access_token.present?
      begin
        decoded = Auth::JsonWebToken.decode(access_token)
        
        # Проверяем, что это access токен
        if decoded[:token_type] == 'access'
          @current_user = User.find(decoded[:user_id])
          
          # Проверяем, что пользователь активен
          unless @current_user.is_active?
            Rails.logger.warn("🚫 Пользователь неактивен: #{@current_user.email}")
            @current_user = nil
          else
            Rails.logger.info("🔐 Пользователь авторизован: #{@current_user.email}")
          end
        else
          Rails.logger.info("👤 Неверный тип токена, работаем как гость")
          @current_user = nil
        end
      rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound => e
        Rails.logger.info("👤 Ошибка токена, работаем как гость: #{e.message}")
        @current_user = nil
      end
    else
      Rails.logger.info("👤 Токен отсутствует, работаем как гость")
      @current_user = nil
    end
  end

  def set_cart
    if current_user
      # Для авторизованных пользователей - обычная корзина
      @cart = current_user.tire_cart || current_user.create_tire_cart!
      Rails.logger.info("🛒 Загружена корзина пользователя: #{@cart.id}")
    else
      # Для гостей - корзина в сессии
      @cart = get_or_create_guest_cart
      Rails.logger.info("👤 Загружена гостевая корзина: #{@cart.id}")
    end
  end

  def get_or_create_guest_cart
    # Пытаемся найти корзину по ID из сессии
    if session[:guest_cart_id]
      cart = TireCart.find_by(id: session[:guest_cart_id], user_id: nil)
      return cart if cart
    end

    # Создаем новую гостевую корзину
    cart = TireCart.create!(user_id: nil)
    session[:guest_cart_id] = cart.id
    cart
  end

  def set_cart_item
    @cart_item = @cart.tire_cart_items.find(params[:item_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Товар в корзине не найден' }, status: :not_found
  end

  def format_unified_cart(cart)
    grouped_items = cart.tire_cart_items.includes(:supplier_tire_product).group_by { |item| item.product_supplier }

    formatted_suppliers = grouped_items.map do |supplier, items|
      {
        id: supplier.id,
        name: supplier.name,
        items: items.map { |item| format_cart_item(item) },
        items_count: items.sum(&:quantity),
        total_amount: items.sum { |item| item.quantity * item.price_at_add }.to_f
      }
    end

    {
      id: cart.id,
      total_items_count: cart.total_items_count,
      total_amount: cart.total_amount.to_f,
      formatted_total_amount: cart.formatted_total_amount,
      suppliers: formatted_suppliers,
      updated_at: cart.updated_at.strftime('%d.%m.%Y %H:%M')
    }
  end

  def format_items_by_supplier(cart)
    cart.items_by_supplier.transform_keys(&:id).transform_values do |items|
      supplier = items.first.supplier
      {
        supplier: {
          id: supplier.id,
          name: supplier.name,
          firm_id: supplier.firm_id
        },
        items: items.map { |item| format_cart_item(item) },
        items_count: items.sum(&:quantity),
        total_amount: items.sum(&:total_price).to_f,
        formatted_total: "#{items.sum(&:total_price).to_f} UAH"
      }
    end
  end

  def format_suppliers_summary(cart)
    cart.supplier_totals.transform_keys(&:id).transform_values do |summary|
      supplier = summary[:items].first.supplier
      {
        supplier: {
          id: supplier.id,
          name: supplier.name,
          firm_id: supplier.firm_id
        },
        items_count: summary[:items_count],
        total_amount: summary[:total_amount].to_f,
        formatted_total: "#{summary[:total_amount].to_f} UAH"
      }
    end
  end

  def format_cart_item(item)
    product = item.supplier_tire_product
    
    {
      id: item.id,
      quantity: item.quantity,
      price_at_add: item.price_at_add.to_f,
      current_price: item.current_price.to_f,
      total_price: item.total_price.to_f,
      formatted_price: item.formatted_price,
      formatted_total: item.formatted_total_price,
      price_changed: item.price_changed?,
      price_change_info: item.price_change_info,
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
      created_at: order.created_at.strftime('%d.%m.%Y %H:%M')
    }
  end
end