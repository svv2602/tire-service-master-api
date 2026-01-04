# frozen_string_literal: true

require 'csv'

# SupplierReportService - generates analytics reports for suppliers
# Supports CSV and Excel (xlsx) formats
class SupplierReportService
  FORMATS = %w[csv xlsx].freeze
  MAX_SYNCHRONOUS_ROWS = 10_000

  def initialize(supplier, params = {})
    @supplier = supplier
    @date_from = parse_date(params[:date_from]) || 30.days.ago.to_date
    @date_to = parse_date(params[:date_to]) || Date.current
    @format = params[:format] || 'csv'
    @report_type = params[:report_type] || 'full'
  end

  # Generate report synchronously (for small datasets)
  def generate
    validate!

    data = collect_report_data

    case @format
    when 'csv'
      generate_csv(data)
    when 'xlsx'
      generate_xlsx(data)
    else
      raise ArgumentError, "Unsupported format: #{@format}"
    end
  end

  # Check if report should be generated in background
  def should_run_in_background?
    estimate_row_count > MAX_SYNCHRONOUS_ROWS
  end

  # Estimate number of rows in the report
  def estimate_row_count
    orders_count = orders_scope.count
    products_count = @supplier.supplier_tire_products.count

    case @report_type
    when 'orders'
      orders_count
    when 'products'
      products_count
    when 'full'
      orders_count + products_count + 100 # Extra rows for summary
    else
      orders_count
    end
  end

  private

  def validate!
    raise ArgumentError, "Invalid format: #{@format}" unless FORMATS.include?(@format)
    raise ArgumentError, "Supplier is required" unless @supplier
    raise ArgumentError, "date_from must be before date_to" if @date_from > @date_to
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def orders_scope
    @supplier.tire_orders
             .where(created_at: @date_from.beginning_of_day..@date_to.end_of_day)
             .includes(:partner, :tire_order_items)
  end

  def collect_report_data
    {
      supplier: @supplier,
      period: { from: @date_from, to: @date_to },
      generated_at: Time.current,
      summary: collect_summary,
      orders: collect_orders_data,
      products: collect_products_data,
      partners: collect_partners_data,
      sales_by_period: collect_sales_by_period
    }
  end

  def collect_summary
    orders = orders_scope
    completed_orders = orders.where(status: %w[completed delivered])

    {
      total_orders: orders.count,
      completed_orders: completed_orders.count,
      total_revenue: completed_orders.sum(:total_amount),
      average_order_value: completed_orders.average(:total_amount)&.round(2) || 0,
      total_items_sold: TireOrderItem.joins(:tire_order)
                                     .where(tire_orders: { id: completed_orders.pluck(:id) })
                                     .sum(:quantity),
      unique_partners: orders.distinct.count(:partner_id),
      products_count: @supplier.supplier_tire_products.count,
      in_stock_products: @supplier.supplier_tire_products.in_stock.count
    }
  end

  def collect_orders_data
    orders_scope.order(created_at: :desc).map do |order|
      {
        id: order.id,
        order_number: format_order_number(order),
        status: order.status,
        partner_name: order.partner&.company_name || order.client_name,
        items_count: order.tire_order_items.count,
        total_amount: order.total_amount,
        created_at: order.created_at,
        shipped_at: order.shipped_at,
        delivered_at: order.delivered_at
      }
    end
  end

  def collect_products_data
    @supplier.supplier_tire_products
             .order(updated_at: :desc)
             .limit(1000)
             .map do |product|
      {
        id: product.id,
        external_id: product.external_id,
        brand: product.brand_normalized,
        model: product.original_model,
        size: product.tire_size,
        season: product.season,
        price: product.price_uah,
        in_stock: product.in_stock,
        stock_status: product.stock_status,
        updated_at: product.updated_at
      }
    end
  end

  def collect_partners_data
    Partner.joins(:tire_orders)
           .where(tire_orders: { supplier_id: @supplier.id })
           .where(tire_orders: { created_at: @date_from.beginning_of_day..@date_to.end_of_day })
           .select('partners.*, COUNT(tire_orders.id) as orders_count, SUM(tire_orders.total_amount) as total_spent')
           .group('partners.id')
           .order('total_spent DESC')
           .limit(100)
           .map do |partner|
      {
        id: partner.id,
        company_name: partner.company_name,
        contact_person: partner.contact_person,
        orders_count: partner.orders_count,
        total_spent: partner.total_spent
      }
    end
  end

  def collect_sales_by_period
    # Use fresh query without includes to avoid MissingAttributeError with aggregations
    @supplier.tire_orders
             .where(created_at: @date_from.beginning_of_day..@date_to.end_of_day)
             .where(status: %w[completed delivered])
             .group("DATE_TRUNC('day', created_at)")
             .select("DATE_TRUNC('day', created_at) as period, SUM(total_amount) as revenue, COUNT(*) as orders_count")
             .order('period')
             .map do |row|
      {
        period: row.period.to_date,
        revenue: row.revenue,
        orders_count: row.orders_count
      }
    end
  end

  def format_order_number(order)
    return order.order_number if order.respond_to?(:order_number) && order.order_number.present?

    "TO-#{order.id.to_s.rjust(6, '0')}"
  end

  def generate_csv(data)
    CSV.generate(headers: true, col_sep: ';', encoding: 'UTF-8') do |csv|
      # Report header
      csv << ["Отчёт поставщика: #{data[:supplier].name}"]
      csv << ["Период: #{data[:period][:from]} - #{data[:period][:to]}"]
      csv << ["Сгенерирован: #{data[:generated_at].strftime('%d.%m.%Y %H:%M')}"]
      csv << []

      # Summary section
      csv << ['СВОДКА']
      csv << ['Показатель', 'Значение']
      csv << ['Всего заказов', data[:summary][:total_orders]]
      csv << ['Выполнено заказов', data[:summary][:completed_orders]]
      csv << ['Общая выручка', format_currency(data[:summary][:total_revenue])]
      csv << ['Средний чек', format_currency(data[:summary][:average_order_value])]
      csv << ['Продано товаров', data[:summary][:total_items_sold]]
      csv << ['Уникальных партнёров', data[:summary][:unique_partners]]
      csv << []

      # Orders section
      csv << ['ЗАКАЗЫ']
      csv << ['ID', 'Номер', 'Статус', 'Партнёр', 'Товаров', 'Сумма', 'Создан', 'Отправлен', 'Доставлен']
      data[:orders].each do |order|
        csv << [
          order[:id],
          order[:order_number],
          translate_status(order[:status]),
          order[:partner_name],
          order[:items_count],
          format_currency(order[:total_amount]),
          format_date(order[:created_at]),
          format_date(order[:shipped_at]),
          format_date(order[:delivered_at])
        ]
      end
      csv << []

      # Products section
      csv << ['ТОВАРЫ (TOP 1000)']
      csv << ['ID', 'Внешний ID', 'Бренд', 'Модель', 'Размер', 'Сезон', 'Цена', 'В наличии', 'Статус склада', 'Обновлён']
      data[:products].each do |product|
        csv << [
          product[:id],
          product[:external_id],
          product[:brand],
          product[:model],
          product[:size],
          product[:season],
          format_currency(product[:price]),
          product[:in_stock] ? 'Да' : 'Нет',
          product[:stock_status],
          format_date(product[:updated_at])
        ]
      end
    end
  end

  def generate_xlsx(data)
    package = Axlsx::Package.new
    wb = package.workbook

    # Summary sheet
    wb.add_worksheet(name: 'Сводка') do |sheet|
      add_xlsx_header(sheet, data)

      sheet.add_row
      sheet.add_row ['СВОДКА'], style: bold_style(wb)
      sheet.add_row ['Показатель', 'Значение']
      sheet.add_row ['Всего заказов', data[:summary][:total_orders]]
      sheet.add_row ['Выполнено заказов', data[:summary][:completed_orders]]
      sheet.add_row ['Общая выручка', format_currency(data[:summary][:total_revenue])]
      sheet.add_row ['Средний чек', format_currency(data[:summary][:average_order_value])]
      sheet.add_row ['Продано товаров', data[:summary][:total_items_sold]]
      sheet.add_row ['Уникальных партнёров', data[:summary][:unique_partners]]
    end

    # Orders sheet
    wb.add_worksheet(name: 'Заказы') do |sheet|
      sheet.add_row ['ID', 'Номер', 'Статус', 'Партнёр', 'Товаров', 'Сумма', 'Создан', 'Отправлен', 'Доставлен'],
                    style: bold_style(wb)

      data[:orders].each do |order|
        sheet.add_row [
          order[:id],
          order[:order_number],
          translate_status(order[:status]),
          order[:partner_name],
          order[:items_count],
          order[:total_amount],
          format_date(order[:created_at]),
          format_date(order[:shipped_at]),
          format_date(order[:delivered_at])
        ]
      end
    end

    # Products sheet
    wb.add_worksheet(name: 'Товары') do |sheet|
      sheet.add_row ['ID', 'Внешний ID', 'Бренд', 'Модель', 'Размер', 'Сезон', 'Цена', 'В наличии', 'Статус', 'Обновлён'],
                    style: bold_style(wb)

      data[:products].each do |product|
        sheet.add_row [
          product[:id],
          product[:external_id],
          product[:brand],
          product[:model],
          product[:size],
          product[:season],
          product[:price],
          product[:in_stock] ? 'Да' : 'Нет',
          product[:stock_status],
          format_date(product[:updated_at])
        ]
      end
    end

    # Partners sheet
    wb.add_worksheet(name: 'Партнёры') do |sheet|
      sheet.add_row ['ID', 'Компания', 'Контактное лицо', 'Заказов', 'Оборот'],
                    style: bold_style(wb)

      data[:partners].each do |partner|
        sheet.add_row [
          partner[:id],
          partner[:company_name],
          partner[:contact_person],
          partner[:orders_count],
          partner[:total_spent]
        ]
      end
    end

    # Sales by period sheet
    wb.add_worksheet(name: 'Продажи по дням') do |sheet|
      sheet.add_row ['Дата', 'Выручка', 'Заказов'],
                    style: bold_style(wb)

      data[:sales_by_period].each do |row|
        sheet.add_row [
          format_date(row[:period]),
          row[:revenue],
          row[:orders_count]
        ]
      end
    end

    package.to_stream.read
  end

  def add_xlsx_header(sheet, data)
    sheet.add_row ["Отчёт поставщика: #{data[:supplier].name}"]
    sheet.add_row ["Период: #{data[:period][:from]} - #{data[:period][:to]}"]
    sheet.add_row ["Сгенерирован: #{data[:generated_at].strftime('%d.%m.%Y %H:%M')}"]
  end

  def bold_style(wb)
    wb.styles.add_style(b: true)
  end

  def format_currency(amount)
    return '' if amount.nil?

    "#{amount.round(2)} ₴"
  end

  def format_date(datetime)
    return '' if datetime.nil?

    datetime.strftime('%d.%m.%Y')
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
end
