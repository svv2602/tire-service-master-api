# frozen_string_literal: true

class Api::V1::SettingsController < ApplicationController
  skip_after_action :verify_authorized
  before_action :authenticate_request
  before_action :authorize_admin!

  # GET /api/v1/settings
  def show
    settings = build_settings_response
    render json: settings
  end

  # PATCH /api/v1/settings
  def update
    # Обновляем отдельные настройки через Application.config или переменные окружения
    # В реальном приложении здесь была бы отдельная модель Settings
    
    settings_params.each do |key, value|
      # Сохраняем настройки в Redis, базе данных или как переменные окружения
      Rails.cache.write("settings_#{key}", value, expires_in: 1.year)
    end

    settings = build_settings_response
    render json: settings
  end

  private

  def authorize_admin!
    unless current_user&.admin?
      render json: { error: 'Доступ запрещен' }, status: :forbidden
    end
  end

  def settings_params
    params.permit(
      :systemName, :contactEmail, :supportPhone, :defaultCityId,
      :slotDuration, :workdayStart, :workdayEnd, :maxBookingsPerDay,
      :enableNotifications, :enableSmsNotifications, :emailNotifications,
      :smsNotifications, :dateFormat, :timeFormat, :bookingLeadTimeHours,
      :workingHoursStart, :workingHoursEnd, :allowWeekendBookings,
      :maintenanceMode, :defaultCurrency, :paymentGateway,
      :maxBookingsPerServicePoint, :timeSlotDurationMinutes
    )
  end

  def build_settings_response
    {
      systemName: get_setting('systemName', 'Система управления шиномонтажом'),
      contactEmail: get_setting('contactEmail', 'admin@example.com'),
      supportPhone: get_setting('supportPhone', '+380631234567'),
      defaultCityId: get_setting('defaultCityId', '1'),
      slotDuration: get_setting('slotDuration', 60).to_i,
      workdayStart: get_setting('workdayStart', '09:00'),
      workdayEnd: get_setting('workdayEnd', '18:00'),
      maxBookingsPerDay: get_setting('maxBookingsPerDay', 100).to_i,
      enableNotifications: get_setting('enableNotifications', true),
      enableSmsNotifications: get_setting('enableSmsNotifications', false),
      emailNotifications: get_setting('emailNotifications', true),
      smsNotifications: get_setting('smsNotifications', false),
      dateFormat: get_setting('dateFormat', 'DD.MM.YYYY'),
      timeFormat: get_setting('timeFormat', '24h'),
      bookingLeadTimeHours: get_setting('bookingLeadTimeHours', 2).to_i,
      workingHoursStart: get_setting('workingHoursStart', '09:00'),
      workingHoursEnd: get_setting('workingHoursEnd', '18:00'),
      allowWeekendBookings: get_setting('allowWeekendBookings', false),
      maintenanceMode: get_setting('maintenanceMode', false),
      defaultCurrency: get_setting('defaultCurrency', 'UAH'),
      paymentGateway: get_setting('paymentGateway', 'wayforpay'),
      maxBookingsPerServicePoint: get_setting('maxBookingsPerServicePoint', 10).to_i,
      timeSlotDurationMinutes: get_setting('timeSlotDurationMinutes', 60).to_i
    }
  end

  def get_setting(key, default_value)
    cached_value = Rails.cache.read("settings_#{key}")
    return cached_value unless cached_value.nil?
    
    # Если нет в кэше, возвращаем значение по умолчанию и кэшируем его
    Rails.cache.write("settings_#{key}", default_value, expires_in: 1.year)
    default_value
  end
end 