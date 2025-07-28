# Сервис для обработки заказов от интернет-магазинов
class OrderProcessorService
  include ActiveModel::Validations
  
  attr_accessor :raw_data, :service_point, :orders
  
  validates :raw_data, presence: true
  validates :service_point, presence: true
  
  def initialize(raw_data, service_point = nil)
    @raw_data = raw_data
    @service_point = service_point
    @orders = []
  end
  
  # Основной метод обработки JSON данных
  def process
    return false unless valid?
    
    begin
      ActiveRecord::Base.transaction do
        parsed_data = parse_json_data
        create_orders_from_data(parsed_data)
      end
      true
    rescue => e
      Rails.logger.error "Ошибка обработки заказов: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      errors.add(:base, "Ошибка обработки заказов: #{e.message}")
      false
    end
  end
  
  # Получение созданных заказов
  def created_orders
    @orders
  end
  
  # Статистика обработки
  def processing_stats
    {
      total_processed: @orders.size,
      successful: @orders.count(&:persisted?),
      failed: @orders.count { |o| !o.persisted? },
      total_amount: @orders.sum(&:total_amount),
      total_items: @orders.sum(&:total_quantity)
    }
  end
  
  private
  
  def parse_json_data
    case @raw_data
    when String
      JSON.parse(@raw_data, symbolize_names: true)
    when Array, Hash
      @raw_data.is_a?(Hash) ? [@raw_data.deep_symbolize_keys] : @raw_data.map(&:deep_symbolize_keys)
    else
      raise "Неподдерживаемый формат данных: #{@raw_data.class}"
    end
  end
  
  def create_orders_from_data(data_array)
    data_array = [data_array] unless data_array.is_a?(Array)
    
    data_array.each do |order_data|
      order = create_single_order(order_data)
      @orders << order if order
    end
  end
  
  def create_single_order(order_data)
    # Поиск или установка сервисной точки
    target_service_point = find_service_point(order_data)
    
    unless target_service_point
      Rails.logger.warn "Сервисная точка не найдена для заказа #{order_data[:ttn]}"
      return nil
    end
    
    # Создание заказа
    order = Order.new(
      service_point: target_service_point,
      status: map_external_status(order_data[:status]),
      order_date: parse_order_date(order_data[:date]),
      ttn: order_data[:ttn],
      number: order_data[:number],
      customer_name: order_data[:klient],
      customer_phone: normalize_phone(order_data[:phone]),
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
      order_data[:goods].each do |good_data|
        order.order_items.build(
          artikul: good_data[:artikul],
          quantity: good_data[:quantity],
          price: good_data[:price],
          sum: good_data[:sum],
          bas_id: good_data[:bas_id],
          name: good_data[:name],
          description: good_data[:description],
          category: good_data[:category],
          brand: good_data[:brand],
          model: good_data[:model]
        )
      end
    end
    
    # Сохранение
    if order.save
      Rails.logger.info "Создан заказ ID: #{order.id}, ТТН: #{order.ttn}"
      order
    else
      Rails.logger.error "Ошибка создания заказа #{order_data[:ttn]}: #{order.errors.full_messages.join(', ')}"
      nil
    end
  end
  
  def find_service_point(order_data)
    return @service_point if @service_point
    
    # Поиск по ID в системе
    point = ServicePoint.find_by(id: order_data[:point_id])
    return point if point
    
    # Поиск по внешнему ID партнера
    point = ServicePoint.joins(:partner)
                       .find_by(partners: { external_id: order_data[:point_id] })
    return point if point
    
    # Поиск по названию точки
    ServicePoint.where("name ILIKE ?", "%#{order_data[:point]}%").first
  end
  
  def map_external_status(external_status)
    case external_status&.downcase
    when 'прийнято', 'принято', 'received'
      'received'
    when 'в обработке', 'processing'
      'processing'
    when 'готов', 'готово', 'ready'
      'ready'
    when 'выдан', 'выдано', 'delivered'
      'delivered'
    when 'отменен', 'отменено', 'canceled'
      'canceled'
    else
      'received' # по умолчанию
    end
  end
  
  def parse_order_date(date_string)
    return DateTime.current unless date_string.present?
    
    # Попытка парсинга в разных форматах
    formats = [
      "%d.%m.%Y %H:%M:%S",
      "%d.%m.%Y %H:%M",
      "%d.%m.%Y",
      "%Y-%m-%d %H:%M:%S",
      "%Y-%m-%d %H:%M",
      "%Y-%m-%d"
    ]
    
    formats.each do |format|
      begin
        return DateTime.strptime(date_string.to_s, format)
      rescue ArgumentError
        next
      end
    end
    
    Rails.logger.warn "Не удалось распарсить дату: #{date_string}"
    DateTime.current
  end
  
  def normalize_phone(phone)
    return phone unless phone.present?
    
    # Убираем все символы кроме цифр
    digits = phone.gsub(/\D/, '')
    
    # Нормализация украинских номеров
    if digits.length == 10 && !digits.start_with?('380')
      digits = "380#{digits}"
    elsif digits.length == 9 && !digits.start_with?('380')
      digits = "380#{digits}"
    end
    
    # Добавляем + если нужно
    digits.start_with?('380') ? "+#{digits}" : phone
  end
end 