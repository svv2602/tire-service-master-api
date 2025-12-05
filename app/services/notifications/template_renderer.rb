# frozen_string_literal: true

module Notifications
  # TemplateRenderer - подготовка и рендеринг шаблонов уведомлений
  # Отвечает за: подстановку переменных, форматирование сообщений
  class TemplateRenderer
    # Подготавливает данные уведомления
    # @param recipient [User, Client] получатель
    # @param notification_type [NotificationType] тип уведомления
    # @param data [Hash] дополнительные данные
    # @return [Hash] подготовленные данные
    def prepare_notification_data(recipient, notification_type, data)
      {
        title: data[:title] || notification_type.name.humanize,
        message: data[:message] || 'No message provided',
        priority: data[:priority] || 'normal',
        category: data[:category] || 'general'
      }.tap do |result|
        if notification_type.template.present? && data[:template_data]
          result[:message] = fill_template(notification_type.template, data[:template_data])
        end
      end
    end

    # Заполняет шаблон переменными
    # @param template [String] шаблон с плейсхолдерами {{variable}}
    # @param data [Hash] переменные для подстановки
    # @return [String] заполненный шаблон
    def fill_template(template, data)
      result = template.dup
      data.each do |key, value|
        result.gsub!("{{#{key}}}", value.to_s)
      end
      result
    end

    # Строит переменные для бронирования
    # @param booking [Booking] объект бронирования
    # @return [Hash] переменные для шаблона
    def build_booking_variables(booking)
      system_variables
        .merge(client_variables(booking))
        .merge(booking_variables(booking))
        .merge(service_point_variables(booking))
        .merge(service_variables(booking))
        .merge(car_variables(booking))
    end

    # Строит переменные для оператора
    # @param operator [Operator] оператор
    # @param service_point [ServicePoint] сервисная точка
    # @param action_type [String] тип действия (assigned/unassigned)
    # @return [Hash] переменные для шаблона
    def build_operator_variables(operator, service_point, action_type)
      {
        operator_name: operator.user.full_name,
        operator_first_name: operator.user.first_name,
        operator_email: operator.user.email,
        operator_phone: operator.user.phone,
        service_point_name: service_point.name,
        service_point_address: service_point.address,
        service_point_phone: service_point.phone,
        partner_name: service_point.partner&.name,
        action_date: Time.current.strftime('%d.%m.%Y'),
        action_type: action_type,
        login_url: frontend_url('/admin/dashboard')
      }
    end

    # Строит Telegram сообщение для назначения оператора
    # @param operator [Operator] оператор
    # @param service_point [ServicePoint] сервисная точка
    # @param action_type [String] тип действия
    # @return [String] форматированное сообщение
    def build_telegram_assignment_message(operator, service_point, action_type)
      case action_type
      when 'assigned'
        <<~MSG.strip
          🎯 *Новое назначение*

          Здравствуйте, #{operator.user.first_name}!

          Вы назначены оператором на сервисную точку:
          📍 *#{service_point.name}*
          📧 #{service_point.address}
          📞 #{service_point.phone}

          Партнер: #{service_point.partner&.name}
          Дата назначения: #{Time.current.strftime('%d.%m.%Y')}

          Войдите в систему для управления бронированиями.
        MSG
      when 'unassigned'
        <<~MSG.strip
          ⚠️ *Отзыв назначения*

          Здравствуйте, #{operator.user.first_name}!

          Ваше назначение на сервисную точку отозвано:
          📍 *#{service_point.name}*
          📧 #{service_point.address}

          Дата отзыва: #{Time.current.strftime('%d.%m.%Y')}

          Обратитесь к партнеру для уточнения деталей.
        MSG
      end
    end

    private

    def system_variables
      {
        'company_name' => 'Tire Service Master',
        'support_email' => ENV.fetch('SUPPORT_EMAIL', 'support@tireservice.ua'),
        'support_phone' => ENV.fetch('SUPPORT_PHONE', '+38 (044) 111-22-33'),
        'website_url' => ENV.fetch('FRONTEND_URL', 'https://tireservice.ua'),
        'current_date' => Date.current.strftime('%d.%m.%Y'),
        'current_time' => Time.current.strftime('%H:%M')
      }
    end

    def client_variables(booking)
      {
        'client_name' => "#{booking.service_recipient_first_name} #{booking.service_recipient_last_name}".strip,
        'client_email' => booking.service_recipient_email || booking.client&.email || '',
        'client_phone' => booking.service_recipient_phone || booking.client&.phone || '',
        'client_first_name' => booking.service_recipient_first_name || booking.client&.first_name || '',
        'client_last_name' => booking.service_recipient_last_name || booking.client&.last_name || ''
      }
    end

    def booking_variables(booking)
      {
        'booking_id' => "##{booking.id}",
        'booking_date' => booking.booking_date&.strftime('%d.%m.%Y') || '',
        'booking_time' => booking.start_time&.strftime('%H:%M') || '',
        'booking_status' => booking.status&.humanize || ''
      }
    end

    def service_point_variables(booking)
      return {} unless booking.service_point

      {
        'service_point_name' => booking.service_point.name || '',
        'service_point_address' => booking.service_point.address || '',
        'service_point_phone' => booking.service_point.contact_phone_for_category(booking.service_category_id) || '',
        'service_point_city' => booking.service_point.city&.name || ''
      }
    end

    def service_variables(booking)
      return {} unless booking.service_category

      {
        'service_name' => booking.service_category.name || '',
        'service_category' => booking.service_category.name || ''
      }
    end

    def car_variables(booking)
      {
        'car_brand' => booking.car_brand || '',
        'car_model' => booking.car_model || '',
        'license_plate' => booking.license_plate || ''
      }
    end

    def frontend_url(path)
      base_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3008')
      "#{base_url}#{path}"
    end
  end
end
