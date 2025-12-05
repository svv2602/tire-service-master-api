# frozen_string_literal: true

module Availability
  # ScheduleResolver - обработка расписания и рабочего времени
  # Отвечает за: сезонные расписания, рабочие часы, праздники
  class ScheduleResolver
    # Дни недели
    DAYS_OF_WEEK = {
      0 => 'sunday',
      1 => 'monday',
      2 => 'tuesday',
      3 => 'wednesday',
      4 => 'thursday',
      5 => 'friday',
      6 => 'saturday'
    }.freeze

    attr_reader :service_point

    def initialize(service_point)
      @service_point = service_point
    end

    # Получение расписания для конкретной даты
    # @param date [Date] дата
    # @return [Hash] информация о расписании
    def schedule_for_date(date)
      day_key = day_key_for_date(date)

      # Сначала проверяем сезонное расписание
      seasonal = check_seasonal_schedule(date, day_key)
      return seasonal if seasonal

      # Если нет сезонного - используем обычное
      regular_schedule(date, day_key)
    end

    # Проверка работает ли точка в указанную дату
    # @param date [Date] дата
    # @return [Boolean]
    def working_on_date?(date)
      schedule_for_date(date)[:is_working]
    end

    # Получение рабочих часов для всех постов
    # @param date [Date] дата
    # @return [Hash] opening_time, closing_time
    def working_hours_for_all_posts(date)
      day_key = day_key_for_date(date)
      schedule_info = schedule_for_date(date)

      working_posts = service_point.service_posts.where(is_active: true).select do |post|
        post_working_on_day?(post, day_key, schedule_info)
      end

      collect_working_hours(working_posts, day_key, schedule_info, date)
    end

    # Получение рабочих часов для категории
    # @param date [Date] дата
    # @param category_id [Integer] ID категории
    # @return [Hash] opening_time, closing_time
    def working_hours_for_category(date, category_id)
      day_key = day_key_for_date(date)
      schedule_info = schedule_for_date(date)

      category_posts = service_point.service_posts.where(
        service_category_id: category_id,
        is_active: true
      )

      working_posts = category_posts.select do |post|
        post_working_on_day?(post, day_key, schedule_info)
      end

      collect_working_hours(working_posts, day_key, schedule_info, date)
    end

    # Проверка есть ли работающие посты в дату
    # @param date [Date] дата
    # @return [Boolean]
    def has_any_working_posts?(date)
      day_key = day_key_for_date(date)
      schedule_info = schedule_for_date(date)

      all_posts = service_point.service_posts.where(is_active: true)
      return false if all_posts.empty?

      all_posts.any? { |post| post_working_on_day?(post, day_key, schedule_info) }
    end

    # Проверка есть ли работающие посты для категории в дату
    # @param date [Date] дата
    # @param category_id [Integer] ID категории
    # @return [Boolean]
    def has_working_posts_for_category?(date, category_id)
      day_key = day_key_for_date(date)
      schedule_info = schedule_for_date(date)

      category_posts = service_point.service_posts.where(
        service_category_id: category_id,
        is_active: true
      )
      return false if category_posts.empty?

      category_posts.any? { |post| post_working_on_day?(post, day_key, schedule_info) }
    end

    # Получить ключ дня недели для даты
    # @param date [Date] дата
    # @return [String] день недели ('monday', 'tuesday', etc.)
    def day_key_for_date(date)
      DAYS_OF_WEEK[date.wday]
    end

    # Получить работающие посты для даты
    # @param date [Date] дата
    # @return [Array<ServicePost>]
    def working_posts_for_date(date)
      day_key = day_key_for_date(date)
      schedule_info = schedule_for_date(date)

      service_point.service_posts.active.select do |post|
        post_working_on_day?(post, day_key, schedule_info)
      end
    end

    # Получить работающие посты для категории и даты
    # @param date [Date] дата
    # @param category_id [Integer] ID категории
    # @return [Array<ServicePost>]
    def working_posts_for_category_and_date(date, category_id)
      day_key = day_key_for_date(date)
      schedule_info = schedule_for_date(date)

      service_point.service_posts
                   .where(service_category_id: category_id, is_active: true)
                   .select { |post| post_working_on_day?(post, day_key, schedule_info) }
    end

    private

    def check_seasonal_schedule(date, day_key)
      seasonal = SeasonalSchedule.find_active_for_date(service_point.id, date)
      return nil unless seasonal

      Rails.logger.info "Availability::ScheduleResolver: Found seasonal schedule '#{seasonal.name}' for point #{service_point.id} on #{date}"

      day_schedule = seasonal.schedule_for_day(day_key)
      return not_working_result('seasonal', seasonal.name, seasonal.id) unless day_schedule.present?

      is_working = day_schedule['is_working_day'] == true || day_schedule['is_working_day'] == 'true'
      return not_working_result('seasonal', seasonal.name, seasonal.id) unless is_working

      parse_schedule_times(date, day_schedule, 'seasonal', seasonal.name, seasonal.id)
    rescue StandardError => e
      Rails.logger.error "Availability::ScheduleResolver: Error parsing seasonal schedule #{seasonal&.id}: #{e.message}"
      not_working_result('seasonal', seasonal&.name, seasonal&.id)
    end

    def regular_schedule(date, day_key)
      return not_working_result('regular') unless service_point.working_hours.present?

      day_schedule = service_point.working_hours[day_key]
      return not_working_result('regular') unless day_schedule.present?

      is_working = day_schedule['is_working_day'] == true || day_schedule['is_working_day'] == 'true'
      return not_working_result('regular') unless is_working

      parse_schedule_times(date, day_schedule, 'regular')
    rescue StandardError => e
      Rails.logger.error "Availability::ScheduleResolver: Error parsing regular schedule for point #{service_point.id}: #{e.message}"
      not_working_result('regular')
    end

    def parse_schedule_times(date, day_schedule, schedule_type, schedule_name = nil, schedule_id = nil)
      opening_time = Time.parse("#{date} #{day_schedule['start']}:00")
      closing_time = Time.parse("#{date} #{day_schedule['end']}:00")

      {
        is_working: true,
        opening_time: opening_time,
        closing_time: closing_time,
        schedule_type: schedule_type,
        schedule_name: schedule_name,
        schedule_id: schedule_id
      }.compact
    end

    def not_working_result(schedule_type, schedule_name = nil, schedule_id = nil)
      {
        is_working: false,
        schedule_type: schedule_type,
        schedule_name: schedule_name,
        schedule_id: schedule_id
      }.compact
    end

    def post_working_on_day?(post, day_key, schedule_info)
      if post.has_custom_schedule?
        # Пост имеет индивидуальный график (не затрагивается сезонными расписаниями)
        post.working_on_day?(day_key)
      else
        # Пост работает по общему расписанию сервисной точки
        schedule_info[:is_working]
      end
    end

    def collect_working_hours(working_posts, day_key, schedule_info, date)
      opening_times = []
      closing_times = []

      working_posts.each do |post|
        if post.has_custom_schedule?
          opening_times << post.start_time_for_day(day_key)
          closing_times << post.end_time_for_day(day_key)
        elsif schedule_info[:opening_time] && schedule_info[:closing_time]
          opening_times << schedule_info[:opening_time].strftime('%H:%M')
          closing_times << schedule_info[:closing_time].strftime('%H:%M')
        end
      end

      earliest_opening = opening_times.min || '09:00'
      latest_closing = closing_times.max || '18:00'

      {
        opening_time: Time.parse("#{date} #{earliest_opening}:00"),
        closing_time: Time.parse("#{date} #{latest_closing}:00")
      }
    end
  end
end
