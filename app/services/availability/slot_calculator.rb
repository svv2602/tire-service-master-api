# frozen_string_literal: true

module Availability
  # SlotCalculator - расчет временных слотов
  # Отвечает за: генерацию слотов, проверку доступности времени
  class SlotCalculator
    MIN_TIME_INTERVAL = 15 # минут

    attr_reader :service_point, :schedule_resolver

    def initialize(service_point, schedule_resolver: nil)
      @service_point = service_point
      @schedule_resolver = schedule_resolver || ScheduleResolver.new(service_point)
    end

    # Получение ВСЕХ временных слотов с указанием их доступности
    # @param date [Date] дата
    # @return [Array<Hash>] массив слотов
    def all_slots_for_date(date)
      return [] unless schedule_resolver.has_any_working_posts?(date)

      day_key = schedule_resolver.day_key_for_date(date)
      schedule_info = schedule_resolver.schedule_for_date(date)
      working_posts = schedule_resolver.working_posts_for_date(date)

      return [] if working_posts.empty?

      generate_all_slots(date, day_key, schedule_info, working_posts)
    end

    # Получение доступных слотов для даты
    # @param date [Date] дата
    # @return [Array<Hash>]
    def available_slots_for_date(date)
      all_slots_for_date(date).select { |slot| slot[:available] }
    end

    # Получение всех возможных слотов (включая занятые)
    # @param date [Date] дата
    # @return [Array<Hash>]
    def all_possible_slots_for_date(date)
      return [] unless schedule_resolver.has_any_working_posts?(date)

      day_key = schedule_resolver.day_key_for_date(date)
      schedule_info = schedule_resolver.schedule_for_date(date)
      working_posts = schedule_resolver.working_posts_for_date(date)

      return [] if working_posts.empty?

      generate_possible_slots(date, day_key, schedule_info, working_posts)
    end

    # Получение слотов для категории
    # @param date [Date] дата
    # @param category_id [Integer] ID категории
    # @return [Array<Hash>]
    def available_slots_for_category(date, category_id)
      date = Date.parse(date) if date.is_a?(String)

      return [] unless schedule_resolver.has_working_posts_for_category?(date, category_id)

      day_key = schedule_resolver.day_key_for_date(date)
      schedule_info = schedule_resolver.schedule_for_date(date)
      working_posts = schedule_resolver.working_posts_for_category_and_date(date, category_id)

      return [] if working_posts.empty?

      generate_category_slots(date, day_key, schedule_info, working_posts, category_id)
    end

    # Получение всех слотов для категории с информацией о загруженности
    # @param date [Date] дата
    # @param category_id [Integer] ID категории
    # @return [Array<Hash>]
    def all_slots_for_category_with_occupancy(date, category_id)
      date = Date.parse(date) if date.is_a?(String)

      return [] unless schedule_resolver.has_working_posts_for_category?(date, category_id)

      day_key = schedule_resolver.day_key_for_date(date)
      schedule_info = schedule_resolver.schedule_for_date(date)
      working_posts = schedule_resolver.working_posts_for_category_and_date(date, category_id)

      return [] if working_posts.empty?

      generate_category_slots_with_occupancy(date, day_key, schedule_info, working_posts, category_id)
    end

    # Получение всех возможных слотов для категории
    # @param date [Date] дата
    # @param category_id [Integer] ID категории
    # @return [Array<Hash>]
    def all_possible_slots_for_category(date, category_id)
      date = Date.parse(date) if date.is_a?(String)

      return [] unless schedule_resolver.has_working_posts_for_category?(date, category_id)

      day_key = schedule_resolver.day_key_for_date(date)
      schedule_info = schedule_resolver.schedule_for_date(date)
      working_posts = schedule_resolver.working_posts_for_category_and_date(date, category_id)

      return [] if working_posts.empty?

      generate_possible_category_slots(date, day_key, schedule_info, working_posts, category_id)
    end

    # Группировка слотов по времени
    # @param date [Date] дата
    # @param min_duration_minutes [Integer, nil] минимальная длительность
    # @return [Array<Hash>]
    def available_times_for_date(date, min_duration_minutes = nil)
      return [] unless schedule_resolver.has_any_working_posts?(date)

      individual_slots = available_slots_for_date(date)
      return [] if individual_slots.empty?

      day_key = schedule_resolver.day_key_for_date(date)
      schedule_info = schedule_resolver.schedule_for_date(date)

      total_posts = schedule_resolver.working_posts_for_date(date).count

      group_slots_by_time(individual_slots, total_posts, min_duration_minutes)
    end

    # Поиск ближайшего доступного времени
    # @param date [Date] дата
    # @param after_time [Time, nil] после указанного времени
    # @param duration_minutes [Integer] длительность
    # @return [Hash, nil]
    def find_next_available_time(date, after_time = nil, duration_minutes = 60)
      after_time ||= Time.current

      # Ищем в текущем дне
      today_slots = available_times_for_date(date, duration_minutes)
      today_available = today_slots.find { |slot| slot[:datetime] >= after_time }
      return today_available if today_available

      # Ищем в следующих днях (до 30 дней вперед)
      (1..30).each do |days_ahead|
        future_date = date + days_ahead.days
        future_slots = available_times_for_date(future_date, duration_minutes)
        return future_slots.first if future_slots.any?
      end

      nil
    end

    private

    def generate_all_slots(date, day_key, schedule_info, working_posts)
      first_post = working_posts.first
      total_posts_count = working_posts.count

      start_time, end_time = resolve_working_hours(first_post, day_key, schedule_info, date)
      slot_duration = first_post.slot_duration

      all_slots = []
      current_time = start_time

      while current_time + slot_duration.minutes <= end_time
        slot_end_time = current_time + slot_duration.minutes
        bookings_count = count_bookings_at_time(date, current_time)

        (1..total_posts_count).each do |post_index|
          is_available = post_index > bookings_count

          all_slots << {
            service_post_id: working_posts[post_index - 1]&.id,
            post_number: post_index,
            post_name: "Пост #{post_index}",
            start_time: current_time.strftime('%H:%M'),
            end_time: slot_end_time.strftime('%H:%M'),
            duration_minutes: slot_duration,
            datetime: current_time,
            available: is_available,
            bookings_count: bookings_count,
            total_posts: total_posts_count
          }
        end

        current_time = slot_end_time
      end

      all_slots.sort_by { |slot| [slot[:datetime], slot[:post_number]] }
    end

    def generate_possible_slots(date, day_key, schedule_info, working_posts)
      all_slots = []

      working_posts.each do |post|
        start_time, end_time = resolve_working_hours(post, day_key, schedule_info, date)
        slot_duration = post.slot_duration
        current_time = start_time

        while current_time + slot_duration.minutes <= end_time
          slot_end_time = current_time + slot_duration.minutes

          all_slots << {
            service_post_id: post.id,
            post_number: post.post_number,
            post_name: post.name,
            start_time: current_time.strftime('%H:%M'),
            end_time: slot_end_time.strftime('%H:%M'),
            duration_minutes: slot_duration,
            datetime: current_time
          }

          current_time = slot_end_time
        end
      end

      all_slots.sort_by { |slot| slot[:datetime] }
    end

    def generate_category_slots(date, day_key, schedule_info, working_posts, category_id)
      time_slots = build_time_slots_map(working_posts, day_key, schedule_info, date)

      available_slots = []

      time_slots.each do |time_key, slot_data|
        bookings_count = count_category_bookings_at_time(date, time_key, category_id)
        available_posts_count = slot_data[:total_posts] - bookings_count

        next unless available_posts_count > 0

        first_post = slot_data[:posts].first
        slot_end_time = slot_data[:datetime] + first_post[:duration_minutes].minutes

        available_slots << {
          service_post_id: first_post[:service_post_id],
          post_number: first_post[:post_number],
          post_name: first_post[:post_name],
          category_id: category_id,
          category_name: working_posts.first.category_name,
          start_time: time_key,
          end_time: slot_end_time.strftime('%H:%M'),
          duration_minutes: first_post[:duration_minutes],
          datetime: slot_data[:datetime],
          available_posts: available_posts_count,
          total_posts: slot_data[:total_posts],
          bookings_count: bookings_count
        }
      end

      available_slots.sort_by { |slot| slot[:datetime] }
    end

    def generate_category_slots_with_occupancy(date, day_key, schedule_info, working_posts, category_id)
      time_slots = build_time_slots_map(working_posts, day_key, schedule_info, date)

      all_slots = []

      time_slots.each do |time_key, slot_data|
        bookings_count = count_category_bookings_at_time(date, time_key, category_id)
        available_posts_count = slot_data[:total_posts] - bookings_count

        first_post = slot_data[:posts].first
        slot_end_time = slot_data[:datetime] + first_post[:duration_minutes].minutes

        all_slots << {
          service_post_id: first_post[:service_post_id],
          post_number: first_post[:post_number],
          post_name: first_post[:post_name],
          category_id: category_id,
          category_name: working_posts.first.category_name,
          start_time: time_key,
          end_time: slot_end_time.strftime('%H:%M'),
          duration_minutes: first_post[:duration_minutes],
          datetime: slot_data[:datetime],
          available_posts: available_posts_count,
          total_posts: slot_data[:total_posts],
          bookings_count: bookings_count,
          is_available: available_posts_count > 0,
          occupancy_status: available_posts_count > 0 ? 'available' : 'full'
        }
      end

      all_slots.sort_by { |slot| slot[:datetime] }
    end

    def generate_possible_category_slots(date, day_key, schedule_info, working_posts, category_id)
      all_slots = []

      working_posts.each do |post|
        start_time, end_time = resolve_working_hours(post, day_key, schedule_info, date)
        slot_duration = post.slot_duration
        current_time = start_time

        while current_time + slot_duration.minutes <= end_time
          slot_end_time = current_time + slot_duration.minutes

          all_slots << {
            service_post_id: post.id,
            post_number: post.post_number,
            post_name: post.name,
            category_id: category_id,
            start_time: current_time.strftime('%H:%M'),
            end_time: slot_end_time.strftime('%H:%M'),
            duration_minutes: slot_duration,
            datetime: current_time
          }

          current_time = slot_end_time
        end
      end

      all_slots.sort_by { |slot| slot[:datetime] }
    end

    def build_time_slots_map(working_posts, day_key, schedule_info, date)
      time_slots = {}

      working_posts.each do |post|
        start_time, end_time = resolve_working_hours(post, day_key, schedule_info, date)
        slot_duration = post.slot_duration
        current_time = start_time

        while current_time + slot_duration.minutes <= end_time
          time_key = current_time.strftime('%H:%M')

          time_slots[time_key] ||= {
            datetime: current_time,
            posts: [],
            total_posts: 0
          }

          time_slots[time_key][:posts] << {
            service_post_id: post.id,
            post_number: post.post_number,
            post_name: post.name || "Пост #{post.post_number}",
            duration_minutes: slot_duration
          }
          time_slots[time_key][:total_posts] += 1

          current_time += slot_duration.minutes
        end
      end

      time_slots
    end

    def resolve_working_hours(post, day_key, schedule_info, date)
      if post.has_custom_schedule?
        start_str = post.start_time_for_day(day_key)
        end_str = post.end_time_for_day(day_key)
      elsif schedule_info[:opening_time] && schedule_info[:closing_time]
        start_str = schedule_info[:opening_time].strftime('%H:%M')
        end_str = schedule_info[:closing_time].strftime('%H:%M')
      else
        start_str = post.start_time_for_day(day_key)
        end_str = post.end_time_for_day(day_key)
      end

      [
        Time.parse("#{date} #{start_str}"),
        Time.parse("#{date} #{end_str}")
      ]
    end

    def group_slots_by_time(individual_slots, total_posts, min_duration_minutes)
      grouped_slots = individual_slots.group_by { |slot| slot[:start_time] }

      grouped_slots.filter_map do |time, slots|
        available_posts_count = slots.count

        next if min_duration_minutes && slots.none? { |slot| slot[:duration_minutes] >= min_duration_minutes }

        {
          time: time,
          datetime: slots.first[:datetime],
          available_posts: available_posts_count,
          total_posts: total_posts
        }
      end.sort_by { |slot| slot[:datetime] }
    end

    def count_bookings_at_time(date, start_time)
      slot_start_str = start_time.strftime('%H:%M:%S')

      Booking.where(
        service_point_id: service_point.id,
        booking_date: date,
        start_time: slot_start_str
      ).where.not(
        status: BookingStatuses::CANCELLED_STATUSES.map(&:to_s)
      ).count
    end

    def count_category_bookings_at_time(date, time_key, category_id)
      Booking.joins(:service_category)
             .where(
               service_point_id: service_point.id,
               booking_date: date,
               start_time: "#{time_key}:00",
               service_category_id: category_id
             )
             .where.not(
               status_id: BookingStatus.canceled_statuses
             ).count
    end
  end
end
