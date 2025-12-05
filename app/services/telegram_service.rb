# frozen_string_literal: true

require 'httparty'
require 'securerandom'

# TelegramService - backward-compatible facade
# Делегирует вызовы к модульной архитектуре Telegram::Service
#
# Новый код должен использовать напрямую:
# - Telegram::Service - оркестратор
# - Telegram::APIClient - HTTP API
# - Telegram::MessageFormatter - форматирование
# - Telegram::BookingFlow - поток бронирования
# - Telegram::CommandHandler - обработка команд
class TelegramService
  include HTTParty

  base_uri 'https://api.telegram.org'

  delegate :send_message, :edit_message, :answer_callback_query,
           :get_me, :get_chat, :get_updates,
           :set_webhook, :delete_webhook, :get_webhook_info,
           :handle_command, :handle_callback_query, :handle_booking_command,
           :send_notification, :send_bulk_notification, :retry_failed_notifications,
           :format_booking_notification,
           to: :service

  def initialize
    @service = Telegram::Service.new
    Rails.logger.info '✅ TelegramService инициализирован (facade → Telegram::Service)'
  end

  # Для обратной совместимости: методы с позиционными аргументами
  # вместо именованных параметров

  def send_message(chat_id, message, keyboard = nil, parse_mode = 'HTML')
    service.send_message(chat_id, message, keyboard, parse_mode)
  end

  def edit_message(chat_id, message_id, text, keyboard = nil, parse_mode = 'HTML')
    service.edit_message(chat_id, message_id, text, keyboard, parse_mode)
  end

  def answer_callback_query(callback_query_id, text = nil, show_alert = false)
    service.answer_callback_query(callback_query_id, text, show_alert)
  end

  def get_updates(offset = nil)
    service.get_updates(offset)
  end

  # Дополнительные методы, которые могут использоваться напрямую

  def handle_command(chat_id, command, user_data = {})
    service.handle_command(chat_id, command, user_data)
  end

  def handle_callback_query(chat_id, callback_data, message_id = nil, user_data = {})
    service.handle_callback_query(chat_id, callback_data, message_id, user_data)
  end

  # Методы бронирования (для обратной совместимости)

  def handle_booking_step(chat_id, text, session)
    service.booking_flow.handle_step(chat_id, text, session)
  end

  def start_city_selection(chat_id, session)
    service.booking_flow.start_city_selection(chat_id, session)
  end

  def start_service_selection(chat_id, session)
    service.booking_flow.start_service_selection(chat_id, session)
  end

  def start_service_point_selection(chat_id, session)
    service.booking_flow.start_service_point_selection(chat_id, session)
  end

  def start_datetime_selection(chat_id, session)
    service.booking_flow.start_datetime_selection(chat_id, session)
  end

  def start_car_type_selection(chat_id, session)
    service.booking_flow.start_car_type_selection(chat_id, session)
  end

  def start_phone_input(chat_id, session)
    service.booking_flow.start_phone_input(chat_id, session)
  end

  def start_license_plate_input(chat_id, session)
    service.booking_flow.start_license_plate_input(chat_id, session)
  end

  def start_comment_input(chat_id, session)
    service.booking_flow.start_comment_input(chat_id, session)
  end

  def show_booking_confirmation(chat_id, session)
    service.booking_flow.show_confirmation(chat_id, session)
  end

  # Методы форматирования клавиатур (для обратной совместимости)

  def build_cities_keyboard(cities)
    service.formatter.build_cities_keyboard(cities)
  end

  def build_service_categories_keyboard(categories)
    service.formatter.build_service_categories_keyboard(categories)
  end

  def build_service_points_keyboard(service_points)
    service.formatter.build_service_points_keyboard(service_points)
  end

  def build_calendar_keyboard
    service.formatter.build_calendar_keyboard
  end

  def build_car_types_keyboard(car_types)
    service.formatter.build_car_types_keyboard(car_types)
  end

  # Доступ к внутренним сервисам
  def api_client
    service.api_client
  end

  def formatter
    service.formatter
  end

  def booking_flow
    service.booking_flow
  end

  def command_handler
    service.command_handler
  end

  private

  attr_reader :service
end
