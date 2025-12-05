# frozen_string_literal: true

module Availability
  # Service - главный оркестратор для работы с доступностью
  # Композирует ScheduleResolver, SlotCalculator, OccupancyTracker
  class Service
    MIN_TIME_INTERVAL = 15

    attr_reader :service_point, :schedule_resolver, :slot_calculator, :occupancy_tracker

    def initialize(service_point)
      @service_point = service_point.is_a?(Integer) ? ServicePoint.find(service_point) : service_point
      @schedule_resolver = ScheduleResolver.new(@service_point)
      @slot_calculator = SlotCalculator.new(@service_point, schedule_resolver: @schedule_resolver)
      @occupancy_tracker = OccupancyTracker.new(@service_point, 
                                                  schedule_resolver: @schedule_resolver,
                                                  slot_calculator: @slot_calculator)
    end

    # === Основные методы для слотов ===

    # Все слоты с доступностью для даты
    def all_slots_for_date(date)
      slot_calculator.all_slots_for_date(date)
    end

    # Доступные слоты для даты
    def available_slots_for_date(date)
      slot_calculator.available_slots_for_date(date)
    end

    # Сгруппированные доступные времена
    def available_times_for_date(date, min_duration_minutes = nil)
      slot_calculator.available_times_for_date(date, min_duration_minutes)
    end

    # Слоты для категории
    def available_slots_for_category(date, category_id)
      slot_calculator.available_slots_for_category(date, category_id)
    end

    # Все слоты для категории с занятостью
    def all_slots_for_category_with_occupancy(date, category_id)
      slot_calculator.all_slots_for_category_with_occupancy(date, category_id)
    end

    # === Проверка доступности ===

    # Проверка доступности времени
    def check_availability_at_time(date, time, duration_minutes = nil, exclude_booking_id: nil, category_id: nil)
      occupancy_tracker.check_availability_at_time(date, time, duration_minutes, 
                                                    exclude_booking_id: exclude_booking_id,
                                                    category_id: category_id)
    end

    # Проверка доступности с категорией
    def check_availability_with_category(date, start_time, duration, category_id)
      occupancy_tracker.check_availability_with_category(date, start_time, duration, category_id)
    end

    # === Поиск ===

    # Поиск ближайшего доступного времени
    def find_next_available_time(date, after_time = nil, duration_minutes = 60)
      slot_calculator.find_next_available_time(date, after_time, duration_minutes)
    end

    # === Занятость ===

    # Детали занятости за день
    def day_occupancy_details(date)
      occupancy_tracker.day_occupancy_details(date)
    end

    # Детали занятости для категории
    def day_occupancy_details_for_category(date, category_id)
      occupancy_tracker.day_occupancy_details_for_category(date, category_id)
    end

    # Подсчет бронирований
    def count_bookings_at_time(date, start_time, end_time)
      occupancy_tracker.count_bookings_at_time(date, start_time, end_time)
    end

    # Проверка занятости слота
    def is_slot_occupied?(date, start_time, end_time)
      occupancy_tracker.slot_occupied?(date, start_time, end_time)
    end

    # === Расписание ===

    # Информация о расписании
    def schedule_for_date(date)
      schedule_resolver.schedule_for_date(date)
    end

    # Работает ли точка в дату
    def working_on_date?(date)
      schedule_resolver.working_on_date?(date)
    end

    # Рабочие часы
    def working_hours_for_all_posts(date)
      schedule_resolver.working_hours_for_all_posts(date)
    end

    def working_hours_for_category(date, category_id)
      schedule_resolver.working_hours_for_category(date, category_id)
    end

    # Есть ли работающие посты
    def has_any_working_posts?(date)
      schedule_resolver.has_any_working_posts?(date)
    end

    def has_working_posts_for_category?(date, category_id)
      schedule_resolver.has_working_posts_for_category?(date, category_id)
    end

    # === Вспомогательные ===

    def all_possible_slots_for_date(date)
      slot_calculator.all_possible_slots_for_date(date)
    end

    def all_possible_slots_for_category(date, category_id)
      slot_calculator.all_possible_slots_for_category(date, category_id)
    end
  end
end
