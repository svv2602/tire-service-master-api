# frozen_string_literal: true

module Availability
  # OccupancyTracker - отслеживание загруженности
  # Отвечает за: метрики занятости, подсчет бронирований, статистика
  class OccupancyTracker
    MIN_TIME_INTERVAL = 15 # минут

    attr_reader :service_point, :schedule_resolver, :slot_calculator

    def initialize(service_point, schedule_resolver: nil, slot_calculator: nil)
      @service_point = service_point
      @schedule_resolver = schedule_resolver || ScheduleResolver.new(service_point)
      @slot_calculator = slot_calculator || SlotCalculator.new(service_point, schedule_resolver: @schedule_resolver)
    end

    # Детальная информация о загрузке на день
    # @param date [Date] дата
    # @return [Hash]
    def day_occupancy_details(date)
      unless schedule_resolver.has_any_working_posts?(date)
        return {
          is_working: false,
          message: 'В выбранную дату сервисная точка не работает. Пожалуйста, выберите другую дату.'
        }
      end

      available_slots = slot_calculator.available_slots_for_date(date)
      all_possible_slots = slot_calculator.all_possible_slots_for_date(date)

      total_slots = all_possible_slots.count
      available_slots_count = available_slots.count
      occupied_slots_count = total_slots - available_slots_count
      occupancy_percentage = total_slots > 0 ? (occupied_slots_count.to_f / total_slots * 100).round(1) : 0

      working_hours_info = schedule_resolver.working_hours_for_all_posts(date)
      schedule_info = schedule_resolver.schedule_for_date(date)

      {
        is_working: true,
        opening_time: working_hours_info[:opening_time].strftime('%H:%M'),
        closing_time: working_hours_info[:closing_time].strftime('%H:%M'),
        total_posts: service_point.service_posts.active.count,
        schedule_info: {
          schedule_type: schedule_info[:schedule_type],
          schedule_name: schedule_info[:schedule_name],
          schedule_id: schedule_info[:schedule_id]
        }.compact,
        summary: build_summary(total_slots, available_slots_count, occupied_slots_count, occupancy_percentage)
      }
    end

    # Детальная информация о загрузке для категории
    # @param date [Date] дата
    # @param category_id [Integer] ID категории
    # @return [Hash]
    def day_occupancy_details_for_category(date, category_id)
      unless schedule_resolver.has_working_posts_for_category?(date, category_id)
        return {
          is_working: false,
          message: 'В выбранную дату сервисная точка не работает с услугами данной категории. Пожалуйста, выберите другую дату.',
          category_id: category_id
        }
      end

      available_slots = slot_calculator.available_slots_for_category(date, category_id)
      all_possible_slots = slot_calculator.all_possible_slots_for_category(date, category_id)

      actual_bookings_count = count_category_bookings(date, category_id)

      total_slots = all_possible_slots.count
      available_slots_count = available_slots.count
      occupied_slots_count = actual_bookings_count
      occupancy_percentage = total_slots > 0 ? (occupied_slots_count.to_f / total_slots * 100).round(1) : 0

      category_posts_count = service_point.posts_count_for_category(category_id)
      working_hours_info = schedule_resolver.working_hours_for_category(date, category_id)
      schedule_info = schedule_resolver.schedule_for_date(date)

      {
        is_working: true,
        opening_time: working_hours_info[:opening_time].strftime('%H:%M'),
        closing_time: working_hours_info[:closing_time].strftime('%H:%M'),
        total_posts: category_posts_count,
        category_id: category_id,
        schedule_info: {
          schedule_type: schedule_info[:schedule_type],
          schedule_name: schedule_info[:schedule_name],
          schedule_id: schedule_info[:schedule_id]
        }.compact,
        summary: build_summary(total_slots, available_slots_count, occupied_slots_count, occupancy_percentage)
      }
    end

    # Подсчет занятых постов в конкретное время
    # @param date [Date] дата
    # @param time [Time] время
    # @param exclude_booking_id [Integer, nil] исключить бронирование
    # @return [Integer]
    def count_occupied_posts_at_time(date, time, exclude_booking_id: nil)
      time_string = time.strftime('%H:%M:%S')

      query = Booking.where(
        service_point_id: service_point.id,
        booking_date: date,
        start_time: time_string
      ).where.not(status_id: BookingStatus.canceled_statuses)

      query = query.where.not(id: exclude_booking_id) if exclude_booking_id.present?

      query.count
    end

    # Подсчет бронирований в конкретное время
    # @param date [Date] дата
    # @param start_time [Time] время начала
    # @param end_time [Time] время окончания
    # @return [Integer]
    def count_bookings_at_time(date, start_time, _end_time)
      slot_start_str = start_time.strftime('%H:%M:%S')

      Booking.where(
        service_point_id: service_point.id,
        booking_date: date,
        start_time: slot_start_str
      ).where.not(
        status: BookingStatuses::CANCELLED_STATUSES.map(&:to_s)
      ).count
    end

    # Проверка занят ли слот
    # @param date [Date] дата
    # @param start_time [Time] время начала
    # @param end_time [Time] время окончания
    # @return [Boolean]
    def slot_occupied?(date, start_time, end_time)
      count_bookings_at_time(date, start_time, end_time) > 0
    end

    # Проверка доступности времени
    # @param date [Date] дата
    # @param time [Time, String] время
    # @param duration_minutes [Integer, nil] длительность
    # @param exclude_booking_id [Integer, nil] исключить бронирование
    # @param category_id [Integer, nil] ID категории
    # @return [Hash]
    def check_availability_at_time(date, time, duration_minutes = nil, exclude_booking_id: nil, category_id: nil)
      # Проверяем есть ли работающие посты
      if category_id.present?
        return not_available('Не рабочий день') unless schedule_resolver.has_working_posts_for_category?(date, category_id)
        working_hours_info = schedule_resolver.working_hours_for_category(date, category_id)
      else
        return not_available('Не рабочий день') unless schedule_resolver.has_any_working_posts?(date)
        working_hours_info = schedule_resolver.working_hours_for_all_posts(date)
      end

      # Проверяем время в рамках рабочих часов
      opening_time = working_hours_info[:opening_time]
      closing_time = working_hours_info[:closing_time]
      check_time = time.is_a?(String) ? Time.parse("#{date} #{time}") : time

      return not_available('Вне рабочих часов') if check_time < opening_time || check_time >= closing_time

      # Получаем доступные слоты
      available_slots = if category_id.present?
                          slot_calculator.available_slots_for_category(date, category_id)
                        else
                          slot_calculator.available_slots_for_date(date)
                        end

      matching_slot = available_slots.find { |slot| slot[:start_time] == check_time.strftime('%H:%M') }

      return not_available('Нет доступного слота в указанное время') unless matching_slot

      actual_duration = duration_minutes || matching_slot[:duration_minutes]

      if actual_duration > matching_slot[:duration_minutes]
        return {
          available: false,
          reason: "Недостаточная длительность слота (доступно #{matching_slot[:duration_minutes]} мин, требуется #{actual_duration} мин)",
          available_duration: matching_slot[:duration_minutes],
          requested_duration: actual_duration
        }
      end

      # Получаем количество постов
      total_posts = calculate_total_posts(date, category_id)
      return not_available('Нет активных постов') if total_posts.zero?

      # Проверяем доступность на весь период
      end_time = check_time + actual_duration.minutes
      current_time = check_time

      while current_time < end_time
        occupied_posts = count_occupied_posts_at_time(date, current_time, exclude_booking_id: exclude_booking_id)
        available_posts = total_posts - occupied_posts

        if available_posts <= 0
          return {
            available: false,
            reason: "Все посты заняты в #{current_time.strftime('%H:%M')}",
            total_posts: total_posts,
            occupied_posts: occupied_posts,
            available_posts: available_posts
          }
        end

        current_time += MIN_TIME_INTERVAL.minutes
      end

      occupied = count_occupied_posts_at_time(date, check_time, exclude_booking_id: exclude_booking_id)

      {
        available: true,
        total_posts: total_posts,
        occupied_posts: occupied,
        available_posts: total_posts - occupied
      }
    end

    # Проверка доступности с учетом категории
    # @param date [Date] дата
    # @param start_time [String] время начала
    # @param duration [Integer] длительность
    # @param category_id [Integer] ID категории
    # @return [Hash]
    def check_availability_with_category(date, start_time, duration, category_id)
      available_posts = service_point.posts_for_category(category_id)

      return {
        available: false,
        reason: 'Нет активных постов для данной категории услуг',
        available_posts_count: 0,
        total_posts_count: 0
      } if available_posts.empty?

      datetime = DateTime.parse("#{date} #{start_time}")
      end_datetime = datetime + duration.minutes

      available_posts_count = 0

      available_posts.each do |post|
        next unless post.available_at_time?(datetime)

        overlapping_bookings = Booking.where(service_point: service_point)
                                      .where(booking_date: date)
                                      .where('start_time < ? AND end_time > ?',
                                             end_datetime.strftime('%H:%M'),
                                             start_time)
                                      .where.not(status_id: BookingStatus.canceled_statuses)
                                      .count

        available_posts_count += 1 if overlapping_bookings.zero?
      end

      {
        available: available_posts_count > 0,
        reason: available_posts_count > 0 ? nil : 'Все посты данной категории заняты в указанное время',
        available_posts_count: available_posts_count,
        total_posts_count: available_posts.count,
        category_id: category_id
      }
    end

    private

    def build_summary(total_slots, available_slots_count, occupied_slots_count, occupancy_percentage)
      {
        total_slots: total_slots,
        available_slots: available_slots_count,
        occupied_slots: occupied_slots_count,
        occupancy_percentage: occupancy_percentage,
        total_intervals: total_slots,
        busy_intervals: occupied_slots_count,
        free_intervals: available_slots_count,
        average_occupancy_rate: occupancy_percentage,
        peak_occupancy_rate: occupancy_percentage
      }
    end

    def not_available(reason)
      { available: false, reason: reason }
    end

    def count_category_bookings(date, category_id)
      Booking.joins(:service_category)
             .where(
               service_point_id: service_point.id,
               booking_date: date,
               service_category_id: category_id
             )
             .where.not(status_id: BookingStatus.canceled_statuses)
             .count
    end

    def calculate_total_posts(date, category_id)
      if category_id.present?
        service_point.service_posts.where(service_category_id: category_id, is_active: true).count
      else
        schedule_resolver.working_posts_for_date(date).count
      end
    end
  end
end
