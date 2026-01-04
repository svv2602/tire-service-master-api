# frozen_string_literal: true

# SupplierNotificationService - handles notifications for suppliers
# Supports email and Telegram channels
class SupplierNotificationService
  NOTIFICATION_TYPES = {
    new_order: 'new_order',
    order_cancelled: 'order_cancelled',
    order_status_changed: 'order_status_changed',
    low_stock_alert: 'low_stock_alert',
    price_upload_completed: 'price_upload_completed',
    price_upload_failed: 'price_upload_failed'
  }.freeze

  def initialize(supplier)
    @supplier = supplier
  end

  def telegram_service
    @telegram_service ||= TelegramService.new
  end

  # Notify supplier about new order
  def notify_new_order(order)
    return unless @supplier

    data = build_order_data(order)

    # Send email if supplier has email
    send_email(:new_order, data) if @supplier.email.present?

    # Send Telegram if supplier has telegram_chat_id
    send_telegram(:new_order, data) if @supplier.telegram_chat_id.present?

    log_notification(:new_order, order.id)
  end

  # Notify supplier about order cancellation
  def notify_order_cancelled(order, reason = nil)
    return unless @supplier

    data = build_order_data(order).merge(cancellation_reason: reason)

    send_email(:order_cancelled, data) if @supplier.email.present?
    send_telegram(:order_cancelled, data) if @supplier.telegram_chat_id.present?

    log_notification(:order_cancelled, order.id)
  end

  # Notify supplier about order status change
  def notify_order_status_changed(order, old_status, new_status)
    return unless @supplier

    data = build_order_data(order).merge(
      old_status: old_status,
      new_status: new_status
    )

    send_email(:order_status_changed, data) if @supplier.email.present?
    send_telegram(:order_status_changed, data) if @supplier.telegram_chat_id.present?

    log_notification(:order_status_changed, order.id)
  end

  # Notify supplier about low stock
  def notify_low_stock(products)
    return unless @supplier
    return if products.blank?

    data = {
      products_count: products.count,
      products: products.map { |p| { id: p.id, name: p.name, stock_status: p.stock_status } }
    }

    send_email(:low_stock_alert, data) if @supplier.email.present?
    send_telegram(:low_stock_alert, data) if @supplier.telegram_chat_id.present?

    log_notification(:low_stock_alert, nil)
  end

  # Notify supplier about price upload completion
  def notify_price_upload_completed(version, statistics)
    return unless @supplier

    data = {
      version: version,
      statistics: statistics
    }

    send_email(:price_upload_completed, data) if @supplier.email.present?
    send_telegram(:price_upload_completed, data) if @supplier.telegram_chat_id.present?

    log_notification(:price_upload_completed, nil)
  end

  # Notify supplier about price upload failure
  def notify_price_upload_failed(error_message)
    return unless @supplier

    data = { error_message: error_message }

    send_email(:price_upload_failed, data) if @supplier.email.present?
    send_telegram(:price_upload_failed, data) if @supplier.telegram_chat_id.present?

    log_notification(:price_upload_failed, nil)
  end

  # Notify supplier that a report is ready for download
  def notify_report_ready(download_url, filename)
    return unless @supplier

    data = { download_url: download_url, filename: filename }

    # Telegram only - fast notification with download link
    send_telegram(:report_ready, data) if @supplier.telegram_chat_id.present?

    log_notification(:report_ready, nil)
  end

  private

  def build_order_data(order)
    {
      order_id: order.id,
      order_number: format_order_number(order),
      status: order.status,
      partner_name: order.partner&.company_name || order.client_name,
      items_count: calculate_items_count(order),
      total_amount: order.total_amount,
      created_at: order.created_at
    }
  end

  def format_order_number(order)
    # Use order_number if available, otherwise format ID
    return order.order_number if order.respond_to?(:order_number) && order.order_number.present?

    "TO-#{order.id.to_s.rjust(6, '0')}"
  end

  def calculate_items_count(order)
    return order.items_count if order.respond_to?(:items_count) && order.items_count.present?
    return order.tire_order_items.count if order.respond_to?(:tire_order_items)

    0
  end

  def send_email(notification_type, data)
    SupplierMailer.send(notification_type, @supplier, data).deliver_later
  rescue StandardError => e
    Rails.logger.error "Failed to send email to supplier #{@supplier.id}: #{e.message}"
  end

  def send_telegram(notification_type, data)
    message = format_telegram_message(notification_type, data)
    telegram_service.send_message(@supplier.telegram_chat_id, message)
  rescue StandardError => e
    Rails.logger.error "Failed to send Telegram to supplier #{@supplier.id}: #{e.message}"
  end

  def format_telegram_message(notification_type, data)
    case notification_type
    when :new_order
      format_new_order_message(data)
    when :order_cancelled
      format_order_cancelled_message(data)
    when :order_status_changed
      format_order_status_changed_message(data)
    when :low_stock_alert
      format_low_stock_message(data)
    when :price_upload_completed
      format_price_upload_completed_message(data)
    when :price_upload_failed
      format_price_upload_failed_message(data)
    when :report_ready
      format_report_ready_message(data)
    else
      "Уведомление: #{notification_type}"
    end
  end

  def format_new_order_message(data)
    <<~MESSAGE
      🆕 <b>Новый заказ!</b>

      📦 Заказ: ##{data[:order_number]}
      🏢 Партнёр: #{data[:partner_name]}
      📊 Количество товаров: #{data[:items_count]}
      💰 Сумма: #{format_currency(data[:total_amount])}
      📅 Дата: #{format_datetime(data[:created_at])}

      Войдите в панель поставщика для обработки заказа.
    MESSAGE
  end

  def format_order_cancelled_message(data)
    reason = data[:cancellation_reason].present? ? "\n❓ Причина: #{data[:cancellation_reason]}" : ''
    <<~MESSAGE
      ❌ <b>Заказ отменён</b>

      📦 Заказ: ##{data[:order_number]}
      🏢 Партнёр: #{data[:partner_name]}#{reason}
    MESSAGE
  end

  def format_order_status_changed_message(data)
    <<~MESSAGE
      🔄 <b>Статус заказа изменён</b>

      📦 Заказ: ##{data[:order_number]}
      📊 Статус: #{translate_status(data[:old_status])} → #{translate_status(data[:new_status])}
    MESSAGE
  end

  def format_low_stock_message(data)
    products_list = data[:products].first(5).map { |p| "• #{p[:name]}" }.join("\n")
    more = data[:products_count] > 5 ? "\n...и ещё #{data[:products_count] - 5} товаров" : ''

    <<~MESSAGE
      ⚠️ <b>Низкий остаток товаров</b>

      #{data[:products_count]} товаров с низким остатком:
      #{products_list}#{more}

      Проверьте раздел "Товары" в панели поставщика.
    MESSAGE
  end

  def format_price_upload_completed_message(data)
    stats = data[:statistics]
    <<~MESSAGE
      ✅ <b>Прайс успешно загружен</b>

      📊 Версия: #{data[:version]}
      📦 Обработано товаров: #{stats[:processed_count]}
      ✅ Успешно: #{stats[:success_count] || stats[:processed_count]}
      ❌ Ошибок: #{stats[:errors_count] || 0}
    MESSAGE
  end

  def format_price_upload_failed_message(data)
    <<~MESSAGE
      ❌ <b>Ошибка загрузки прайса</b>

      #{data[:error_message]}

      Проверьте формат файла и повторите попытку.
    MESSAGE
  end

  def format_report_ready_message(data)
    <<~MESSAGE
      📊 <b>Отчёт готов к скачиванию</b>

      📁 Файл: #{data[:filename]}
      🔗 <a href="#{data[:download_url]}">Скачать отчёт</a>

      ⏰ Ссылка действительна 24 часа.
    MESSAGE
  end

  def format_currency(amount)
    return '0 ₴' unless amount

    "#{number_with_delimiter(amount.round)} ₴"
  end

  def format_datetime(datetime)
    return '-' unless datetime

    datetime.strftime('%d.%m.%Y %H:%M')
  end

  def translate_status(status)
    {
      'draft' => 'Черновик',
      'submitted' => 'Отправлен',
      'pending' => 'Ожидает',
      'confirmed' => 'Подтверждён',
      'processing' => 'В обработке',
      'shipped' => 'Отправлен',
      'delivered' => 'Доставлен',
      'completed' => 'Завершён',
      'cancelled' => 'Отменён'
    }[status] || status
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse
  end

  def log_notification(notification_type, reference_id)
    Rails.logger.info "Supplier #{@supplier.id} notified: #{notification_type} (ref: #{reference_id})"
  end
end
