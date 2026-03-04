# frozen_string_literal: true

# Системные настройки по умолчанию
puts "🔧 Создание системных настроек..."

# Настройки поиска шин
tire_search_settings = [
  {
    key: 'tire_search_enable_llm',
    value: 'false',
    description: 'Включить LLM для обработки сложных запросов поиска шин',
    category: 'tire_search',
    setting_type: 'boolean',
    default_value: 'false'
  },
  {
    key: 'tire_search_cache_ttl',
    value: '3600',
    description: 'Время кеширования результатов поиска шин (секунды)',
    category: 'tire_search',
    setting_type: 'integer',
    default_value: '3600'
  },
  {
    key: 'tire_search_max_results',
    value: '50',
    description: 'Максимальное количество результатов поиска шин',
    category: 'tire_search',
    setting_type: 'integer',
    default_value: '50'
  }
]

# Интеграции (OpenAI, etc.)
integration_settings = [
  {
    key: 'openai_api_key',
    value: '',
    description: 'API ключ OpenAI для LLM обработки запросов',
    category: 'integrations',
    setting_type: 'password',
    default_value: ''
  },
  {
    key: 'openai_model',
    value: 'gpt-4.1-mini',
    description: 'Модель OpenAI для обработки запросов',
    category: 'integrations',
    setting_type: 'select',
    default_value: 'gpt-4.1-mini'
  },
  {
    key: 'openai_max_tokens',
    value: '500',
    description: 'Максимальное количество токенов для OpenAI ответа',
    category: 'integrations',
    setting_type: 'integer',
    default_value: '500'
  },
  {
    key: 'openai_temperature',
    value: '0.1',
    description: 'Температура для OpenAI (0.0-1.0, чем меньше - тем точнее)',
    category: 'integrations',
    setting_type: 'float',
    default_value: '0.1'
  },
  {
    key: 'openai_timeout',
    value: '30',
    description: 'Таймаут запроса к OpenAI (секунды)',
    category: 'integrations',
    setting_type: 'integer',
    default_value: '30'
  }
]

# Общие настройки
general_settings = [
  {
    key: 'app_name',
    value: 'Tire Service',
    description: 'Название приложения',
    category: 'general',
    setting_type: 'string',
    default_value: 'Tire Service'
  },
  {
    key: 'app_version',
    value: '1.0.0',
    description: 'Версия приложения',
    category: 'general',
    setting_type: 'string',
    default_value: '1.0.0'
  },
  {
    key: 'maintenance_mode',
    value: 'false',
    description: 'Режим технического обслуживания',
    category: 'general',
    setting_type: 'boolean',
    default_value: 'false'
  }
]

# Объединяем все настройки
all_settings = tire_search_settings + integration_settings + general_settings

# Создаем или обновляем настройки
all_settings.each do |setting_data|
  setting = SystemSetting.find_or_initialize_by(key: setting_data[:key])
  
  # Обновляем только если настройка новая или изменились метаданные
  if setting.new_record? || setting.description != setting_data[:description]
    setting.assign_attributes(setting_data.merge(updated_by: 'seeds'))
    setting.save!
    
    status = setting.previously_new_record? ? '✅ Создана' : '🔄 Обновлена'
    puts "   #{status}: #{setting.key} (#{setting.category})"
  else
    puts "   ⏭️  Пропущена: #{setting.key} (уже существует)"
  end
end

puts "🎯 Системные настройки готовы! Создано/обновлено: #{all_settings.size} настроек"

# Показываем статистику
categories = SystemSetting.group(:category).count
puts "\n📊 Статистика по категориям:"
categories.each do |category, count|
  puts "   #{category}: #{count} настроек"
end

puts "\n💡 Для настройки LLM:"
puts "   1. Установите openai_api_key в админке (/admin/system-settings)"
puts "   2. Включите tire_search_enable_llm = true"
puts "   3. LLM будет автоматически активироваться для сложных запросов"