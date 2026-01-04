# frozen_string_literal: true

class SupplierMailer < ApplicationMailer
  layout 'mailer'

  # New order notification
  def new_order(supplier, data)
    @supplier = supplier
    @data = data

    mail(
      to: supplier.email,
      subject: "🆕 Новый заказ ##{data[:order_number]}"
    )
  end

  # Order cancelled notification
  def order_cancelled(supplier, data)
    @supplier = supplier
    @data = data

    mail(
      to: supplier.email,
      subject: "❌ Заказ ##{data[:order_number]} отменён"
    )
  end

  # Order status changed notification
  def order_status_changed(supplier, data)
    @supplier = supplier
    @data = data

    mail(
      to: supplier.email,
      subject: "🔄 Статус заказа ##{data[:order_number]} изменён"
    )
  end

  # Low stock alert
  def low_stock_alert(supplier, data)
    @supplier = supplier
    @data = data

    mail(
      to: supplier.email,
      subject: "⚠️ Низкий остаток товаров (#{data[:products_count]} позиций)"
    )
  end

  # Price upload completed
  def price_upload_completed(supplier, data)
    @supplier = supplier
    @data = data

    mail(
      to: supplier.email,
      subject: "✅ Прайс-лист успешно загружен"
    )
  end

  # Price upload failed
  def price_upload_failed(supplier, data)
    @supplier = supplier
    @data = data

    mail(
      to: supplier.email,
      subject: "❌ Ошибка загрузки прайс-листа"
    )
  end

  private

  def format_currency(amount)
    return '0 ₴' unless amount

    "#{number_with_delimiter(amount.round)} ₴"
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse
  end
end
