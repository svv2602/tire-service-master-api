# frozen_string_literal: true

# Сервис для аналитики и статистики поиска шин
# Отслеживает популярные запросы, тренды, производительность поиска
class TireSearchAnalytics
  include Singleton

  # Ключи Redis для хранения аналитики
  REDIS_KEYS = {
    search_queries: 'tire_search:queries',
    popular_queries: 'tire_search:popular',
    search_stats: 'tire_search:stats',
    daily_stats: 'tire_search:daily',
    user_searches: 'tire_search:users',
    performance_metrics: 'tire_search:performance',
    error_tracking: 'tire_search:errors',
    suggestions_cache: 'tire_search:suggestions_cache'
  }.freeze

  # Периоды для статистики
  PERIODS = {
    hour: 3600,
    day: 86400,
    week: 604800,
    month: 2592000
  }.freeze

  def initialize
    @redis = Rails.cache.redis if Rails.cache.respond_to?(:redis)
    @logger = Rails.logger
  end

  # === ОТСЛЕЖИВАНИЕ ПОИСКОВЫХ ЗАПРОСОВ ===

  # Записывает поисковый запрос в аналитику
  def track_search(query, results_count, user_id: nil, filters: {}, response_time: nil)
    return unless redis_available?

    timestamp = Time.current.to_i
    search_data = {
      query: query.strip.downcase,
      original_query: query,
      results_count: results_count,
      timestamp: timestamp,
      user_id: user_id,
      filters: filters,
      response_time: response_time,
      date: Date.current.to_s
    }

    begin
      # Записываем в общую статистику поисков
      redis.zadd(REDIS_KEYS[:search_queries], timestamp, search_data.to_json)
      
      # Обновляем популярные запросы
      update_popular_queries(query, results_count)
      
      # Обновляем дневную статистику
      update_daily_stats(search_data)
      
      # Отслеживаем пользовательские поиски
      track_user_search(user_id, query) if user_id
      
      # Записываем метрики производительности
      track_performance_metrics(response_time, results_count) if response_time
      
      # Очищаем старые данные (старше месяца)
      cleanup_old_data
      
      @logger.info "TireSearchAnalytics: tracked search '#{query}' with #{results_count} results"
    rescue => e
      @logger.error "TireSearchAnalytics tracking error: #{e.message}"
    end
  end

  # Записывает ошибку поиска
  def track_search_error(query, error_type, error_message, user_id: nil)
    return unless redis_available?

    error_data = {
      query: query,
      error_type: error_type,
      error_message: error_message,
      user_id: user_id,
      timestamp: Time.current.to_i,
      date: Date.current.to_s
    }

    begin
      redis.zadd(REDIS_KEYS[:error_tracking], Time.current.to_i, error_data.to_json)
      @logger.warn "TireSearchAnalytics: tracked error for '#{query}': #{error_type}"
    rescue => e
      @logger.error "TireSearchAnalytics error tracking failed: #{e.message}"
    end
  end

  # === ПОЛУЧЕНИЕ СТАТИСТИКИ ===

  # Возвращает популярные поисковые запросы
  def get_popular_queries(limit: 20, period: :week)
    return [] unless redis_available?

    begin
      since_timestamp = (Time.current - PERIODS[period]).to_i
      
      # Получаем данные за период
      queries_data = redis.zrevrangebyscore(
        REDIS_KEYS[:search_queries],
        '+inf',
        since_timestamp,
        limit: [0, 1000]
      )
      
      # Группируем и подсчитываем
      query_counts = Hash.new { |h, k| h[k] = { count: 0, total_results: 0, last_searched: nil } }
      
      queries_data.each do |data_json|
        data = JSON.parse(data_json)
        query = data['query']
        
        query_counts[query][:count] += 1
        query_counts[query][:total_results] += data['results_count'].to_i
        query_counts[query][:last_searched] = [
          query_counts[query][:last_searched],
          Time.at(data['timestamp'])
        ].compact.max
      end
      
      # Сортируем по популярности и возвращаем топ
      popular = query_counts.map do |query, stats|
        {
          query: query,
          count: stats[:count],
          avg_results: stats[:count] > 0 ? (stats[:total_results].to_f / stats[:count]).round(1) : 0,
          last_searched: stats[:last_searched],
          trend: calculate_trend(query, period)
        }
      end.sort_by { |item| -item[:count] }.first(limit)
      
      popular
    rescue => e
      @logger.error "Error getting popular queries: #{e.message}"
      []
    end
  end

  # Возвращает предложения для автодополнения
  def get_search_suggestions(query, limit: 10)
    return [] unless redis_available?
    return [] if query.blank? || query.length < 2

    cache_key = "#{REDIS_KEYS[:suggestions_cache]}:#{query.downcase}"
    
    begin
      # Проверяем кэш
      cached = redis.get(cache_key)
      return JSON.parse(cached) if cached

      # Генерируем предложения
      suggestions = generate_suggestions(query, limit)
      
      # Кэшируем на 1 час
      redis.setex(cache_key, 3600, suggestions.to_json)
      
      suggestions
    rescue => e
      @logger.error "Error getting search suggestions: #{e.message}"
      []
    end
  end

  # Возвращает общую статистику системы поиска
  def get_search_statistics(period: :week)
    return default_statistics unless redis_available?

    begin
      since_timestamp = (Time.current - PERIODS[period]).to_i
      
      # Получаем данные за период
      searches_data = redis.zrevrangebyscore(
        REDIS_KEYS[:search_queries],
        '+inf',
        since_timestamp
      )
      
      errors_data = redis.zrevrangebyscore(
        REDIS_KEYS[:error_tracking],
        '+inf',
        since_timestamp
      )
      
      # Подсчитываем статистику
      total_searches = searches_data.size
      total_errors = errors_data.size
      success_rate = total_searches > 0 ? ((total_searches - total_errors).to_f / total_searches * 100).round(2) : 0
      
      # Анализируем результаты
      results_stats = analyze_results_stats(searches_data)
      performance_stats = analyze_performance_stats(searches_data)
      
      {
        period: period,
        total_searches: total_searches,
        total_errors: total_errors,
        success_rate: success_rate,
        unique_queries: count_unique_queries(searches_data),
        avg_results_per_search: results_stats[:avg_results],
        zero_results_percentage: results_stats[:zero_results_percentage],
        avg_response_time: performance_stats[:avg_response_time],
        popular_queries: get_popular_queries(limit: 10, period: period),
        search_trends: get_search_trends(period),
        error_breakdown: analyze_error_breakdown(errors_data),
        daily_breakdown: get_daily_breakdown(period)
      }
    rescue => e
      @logger.error "Error getting search statistics: #{e.message}"
      default_statistics
    end
  end

  # Возвращает тренды поиска
  def get_search_trends(period: :week)
    return [] unless redis_available?

    begin
      current_period_start = Time.current - PERIODS[period]
      previous_period_start = current_period_start - PERIODS[period]
      
      current_data = get_period_data(current_period_start, Time.current)
      previous_data = get_period_data(previous_period_start, current_period_start)
      
      calculate_trends_comparison(current_data, previous_data)
    rescue => e
      @logger.error "Error getting search trends: #{e.message}"
      []
    end
  end

  # === УПРАВЛЕНИЕ ДАННЫМИ ===

  # Очищает старые данные аналитики
  def cleanup_old_data(older_than: 1.month)
    return unless redis_available?

    cutoff_timestamp = (Time.current - older_than).to_i
    
    begin
      cleaned_count = 0
      
      REDIS_KEYS.each do |key_name, redis_key|
        case key_name
        when :search_queries, :error_tracking
          # Удаляем записи старше cutoff_timestamp
          removed = redis.zremrangebyscore(redis_key, '-inf', cutoff_timestamp)
          cleaned_count += removed
        when :daily_stats
          # Очищаем дневную статистику старше cutoff
          old_keys = redis.keys("#{redis_key}:*").select do |key|
            date_str = key.split(':').last
            begin
              Date.parse(date_str) < (Date.current - older_than.to_i.days)
            rescue
              true # Удаляем некорректные ключи
            end
          end
          redis.del(*old_keys) if old_keys.any?
          cleaned_count += old_keys.size
        end
      end
      
      @logger.info "TireSearchAnalytics: cleaned #{cleaned_count} old records"
      cleaned_count
    rescue => e
      @logger.error "Error cleaning old data: #{e.message}"
      0
    end
  end

  # Сбрасывает всю аналитику (для тестирования)
  def reset_analytics!
    return unless redis_available?

    begin
      keys_to_delete = REDIS_KEYS.values.flat_map do |key|
        redis.keys("#{key}*")
      end
      
      redis.del(*keys_to_delete) if keys_to_delete.any?
      @logger.info "TireSearchAnalytics: reset all analytics data"
    rescue => e
      @logger.error "Error resetting analytics: #{e.message}"
    end
  end

  # Экспортирует аналитику в JSON
  def export_analytics(period: :month)
    {
      exported_at: Time.current.iso8601,
      period: period,
      statistics: get_search_statistics(period: period),
      popular_queries: get_popular_queries(limit: 50, period: period),
      search_trends: get_search_trends(period: period)
    }
  end

  private

  # Проверяет доступность Redis
  def redis_available?
    @redis&.ping == 'PONG'
  rescue
    false
  end

  # Доступ к Redis
  def redis
    @redis ||= Rails.cache.redis if Rails.cache.respond_to?(:redis)
  end

  # Обновляет популярные запросы
  def update_popular_queries(query, results_count)
    normalized_query = query.strip.downcase
    
    # Увеличиваем счетчик для запроса
    redis.zincrby(REDIS_KEYS[:popular_queries], 1, normalized_query)
    
    # Сохраняем дополнительную информацию
    query_info_key = "#{REDIS_KEYS[:popular_queries]}:info:#{normalized_query}"
    query_info = redis.get(query_info_key)
    
    if query_info
      info = JSON.parse(query_info)
      info['total_results'] += results_count
      info['search_count'] += 1
      info['last_searched'] = Time.current.iso8601
      info['avg_results'] = (info['total_results'].to_f / info['search_count']).round(1)
    else
      info = {
        'original_query' => query,
        'total_results' => results_count,
        'search_count' => 1,
        'first_searched' => Time.current.iso8601,
        'last_searched' => Time.current.iso8601,
        'avg_results' => results_count.to_f
      }
    end
    
    redis.setex(query_info_key, PERIODS[:month], info.to_json)
  end

  # Обновляет дневную статистику
  def update_daily_stats(search_data)
    date_key = "#{REDIS_KEYS[:daily_stats]}:#{search_data[:date]}"
    
    # Увеличиваем счетчики
    redis.hincrby(date_key, 'total_searches', 1)
    redis.hincrby(date_key, 'total_results', search_data[:results_count])
    
    if search_data[:results_count] == 0
      redis.hincrby(date_key, 'zero_results', 1)
    end
    
    if search_data[:response_time]
      # Сохраняем время ответа для расчета среднего
      redis.lpush("#{date_key}:response_times", search_data[:response_time])
      redis.ltrim("#{date_key}:response_times", 0, 999) # Ограничиваем размер
    end
    
    # Устанавливаем TTL на месяц
    redis.expire(date_key, PERIODS[:month])
    redis.expire("#{date_key}:response_times", PERIODS[:month])
  end

  # Отслеживает поиски пользователя
  def track_user_search(user_id, query)
    user_key = "#{REDIS_KEYS[:user_searches]}:#{user_id}"
    
    # Добавляем запрос в список пользователя
    redis.lpush(user_key, {
      query: query,
      timestamp: Time.current.to_i
    }.to_json)
    
    # Ограничиваем историю пользователя (последние 100 поисков)
    redis.ltrim(user_key, 0, 99)
    
    # Устанавливаем TTL
    redis.expire(user_key, PERIODS[:month])
  end

  # Отслеживает метрики производительности
  def track_performance_metrics(response_time, results_count)
    metrics_key = REDIS_KEYS[:performance_metrics]
    timestamp = Time.current.to_i
    
    metric_data = {
      response_time: response_time,
      results_count: results_count,
      timestamp: timestamp
    }
    
    redis.zadd(metrics_key, timestamp, metric_data.to_json)
    
    # Удаляем метрики старше недели
    week_ago = (Time.current - 1.week).to_i
    redis.zremrangebyscore(metrics_key, '-inf', week_ago)
  end

  # Вычисляет тренд для запроса
  def calculate_trend(query, period)
    current_period_start = Time.current - PERIODS[period]
    previous_period_start = current_period_start - PERIODS[period]
    
    current_count = count_query_in_period(query, current_period_start, Time.current)
    previous_count = count_query_in_period(query, previous_period_start, current_period_start)
    
    return 'stable' if previous_count == 0 && current_count == 0
    return 'up' if previous_count == 0 && current_count > 0
    return 'down' if previous_count > 0 && current_count == 0
    
    change_percentage = ((current_count - previous_count).to_f / previous_count * 100).round(1)
    
    case change_percentage
    when -Float::INFINITY..-10
      'down'
    when 10..Float::INFINITY
      'up'
    else
      'stable'
    end
  end

  # Подсчитывает запрос в периоде
  def count_query_in_period(query, start_time, end_time)
    searches = redis.zrangebyscore(
      REDIS_KEYS[:search_queries],
      start_time.to_i,
      end_time.to_i
    )
    
    searches.count do |search_json|
      data = JSON.parse(search_json)
      data['query'] == query
    end
  rescue
    0
  end

  # Генерирует предложения для автодополнения
  def generate_suggestions(query, limit)
    query_lower = query.downcase
    suggestions = []
    
    # Получаем популярные запросы, которые содержат введенный текст
    popular_queries = get_popular_queries(limit: 100, period: :month)
    
    matching_queries = popular_queries.select do |item|
      item[:query].include?(query_lower)
    end.first(limit)
    
    suggestions.concat(matching_queries.map do |item|
      {
        text: item[:query],
        type: 'popular',
        search_count: item[:count],
        category: categorize_query(item[:query])
      }
    end)
    
    # Добавляем предложения из базы данных брендов и моделей
    if suggestions.size < limit
      db_suggestions = get_database_suggestions(query, limit - suggestions.size)
      suggestions.concat(db_suggestions)
    end
    
    suggestions.first(limit)
  end

  # Получает предложения из базы данных
  def get_database_suggestions(query, limit)
    suggestions = []
    query_pattern = "%#{query.downcase}%"
    
    # Поиск по брендам
    brands = CarBrand.where("LOWER(name) LIKE ?", query_pattern).limit(limit / 2)
    suggestions.concat(brands.map do |brand|
      {
        text: brand.name,
        type: 'brand',
        category: 'brands'
      }
    end)
    
    # Поиск по моделям
    if suggestions.size < limit
      models = CarModel.joins(:brand)
                       .where("LOWER(car_models.name) LIKE ? OR LOWER(car_brands.name) LIKE ?", 
                              query_pattern, query_pattern)
                       .limit(limit - suggestions.size)
      
      suggestions.concat(models.map do |model|
        {
          text: "#{model.brand.name} #{model.name}",
          type: 'model',
          category: 'models'
        }
      end)
    end
    
    suggestions
  rescue
    []
  end

  # Категоризирует запрос
  def categorize_query(query)
    return 'size' if query.match?(/\d+\/\d+r\d+|r\d+/i)
    return 'brand' if CarBrand.where("LOWER(name) = ?", query.downcase).exists?
    return 'general' if query.match?/(зимн|летн|всесезон|резин|шин)/i
    'other'
  rescue
    'other'
  end

  # Анализирует статистику результатов
  def analyze_results_stats(searches_data)
    return { avg_results: 0, zero_results_percentage: 0 } if searches_data.empty?
    
    total_results = 0
    zero_results_count = 0
    
    searches_data.each do |search_json|
      data = JSON.parse(search_json)
      results_count = data['results_count'].to_i
      total_results += results_count
      zero_results_count += 1 if results_count == 0
    end
    
    {
      avg_results: (total_results.to_f / searches_data.size).round(1),
      zero_results_percentage: (zero_results_count.to_f / searches_data.size * 100).round(1)
    }
  rescue
    { avg_results: 0, zero_results_percentage: 0 }
  end

  # Анализирует статистику производительности
  def analyze_performance_stats(searches_data)
    response_times = searches_data.filter_map do |search_json|
      data = JSON.parse(search_json)
      data['response_time']&.to_f
    end
    
    return { avg_response_time: 0 } if response_times.empty?
    
    {
      avg_response_time: (response_times.sum / response_times.size).round(3)
    }
  rescue
    { avg_response_time: 0 }
  end

  # Подсчитывает уникальные запросы
  def count_unique_queries(searches_data)
    unique_queries = Set.new
    
    searches_data.each do |search_json|
      data = JSON.parse(search_json)
      unique_queries.add(data['query'])
    end
    
    unique_queries.size
  rescue
    0
  end

  # Анализирует типы ошибок
  def analyze_error_breakdown(errors_data)
    error_types = Hash.new(0)
    
    errors_data.each do |error_json|
      data = JSON.parse(error_json)
      error_types[data['error_type']] += 1
    end
    
    error_types
  rescue
    {}
  end

  # Получает дневную разбивку
  def get_daily_breakdown(period)
    days = []
    period_days = PERIODS[period] / PERIODS[:day]
    
    (0...period_days).each do |days_ago|
      date = Date.current - days_ago.days
      date_key = "#{REDIS_KEYS[:daily_stats]}:#{date}"
      
      stats = redis.hgetall(date_key)
      
      days << {
        date: date.to_s,
        searches: stats['total_searches'].to_i,
        results: stats['total_results'].to_i,
        zero_results: stats['zero_results'].to_i
      }
    end
    
    days.reverse
  rescue
    []
  end

  # Получает данные за период
  def get_period_data(start_time, end_time)
    redis.zrangebyscore(
      REDIS_KEYS[:search_queries],
      start_time.to_i,
      end_time.to_i
    ).map { |json| JSON.parse(json) }
  rescue
    []
  end

  # Сравнивает тренды между периодами
  def calculate_trends_comparison(current_data, previous_data)
    current_queries = Hash.new(0)
    previous_queries = Hash.new(0)
    
    current_data.each { |d| current_queries[d['query']] += 1 }
    previous_data.each { |d| previous_queries[d['query']] += 1 }
    
    all_queries = (current_queries.keys + previous_queries.keys).uniq
    
    trends = all_queries.map do |query|
      current_count = current_queries[query]
      previous_count = previous_queries[query]
      
      change = current_count - previous_count
      change_percentage = previous_count > 0 ? (change.to_f / previous_count * 100).round(1) : nil
      
      {
        query: query,
        current_count: current_count,
        previous_count: previous_count,
        change: change,
        change_percentage: change_percentage,
        trend: change > 0 ? 'up' : (change < 0 ? 'down' : 'stable')
      }
    end
    
    trends.sort_by { |t| -t[:current_count] }.first(20)
  rescue
    []
  end

  # Статистика по умолчанию
  def default_statistics
    {
      period: :week,
      total_searches: 0,
      total_errors: 0,
      success_rate: 0,
      unique_queries: 0,
      avg_results_per_search: 0,
      zero_results_percentage: 0,
      avg_response_time: 0,
      popular_queries: [],
      search_trends: [],
      error_breakdown: {},
      daily_breakdown: []
    }
  end
end