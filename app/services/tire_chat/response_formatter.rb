# frozen_string_literal: true

module TireChat
  # Response formatting for different output formats
  # Handles HTML, Markdown, Plain text, and Telegram formatting
  class ResponseFormatter
    FORMATS = %i[html markdown plain telegram].freeze

    attr_reader :locale

    def initialize(locale: 'ru')
      @locale = locale || 'ru'
    end

    # Format recommendations for display
    # @param recommendations [Array<Hash>] Recommendation items
    # @param options [Hash] Formatting options (format:, with_explanation:, with_catalog_button:)
    # @return [String] Formatted message
    def format_recommendations(recommendations, options = {})
      return no_results_message if recommendations.empty?

      format = options[:format] || :markdown
      with_explanation = options.fetch(:with_explanation, true)
      priority_type = options[:priority_type] || 'balanced'

      message = recommendations_title
      message += format_recommendation_items(recommendations, format)
      message += format_explanation(priority_type) if with_explanation
      message
    end

    # Format price segment recommendations
    # @param recommendations [Array<Hash>] Recommendation items
    # @param price_segment [String] Price segment (premium, middle, budget)
    # @return [String] Formatted message
    def format_price_segment_recommendations(recommendations, price_segment)
      return no_results_message if recommendations.empty?

      message = ""
      recommendations.each_with_index do |item, index|
        message += format_recommendation_item(item, index)
      end

      message += format_segment_explanation(price_segment)
      message += format_continuation_options
      message
    end

    # Format single recommendation item
    def format_recommendation_item(item, index)
      product = item[:product]
      suppliers_count = item[:suppliers_count] || 1
      price_savings = item[:price_savings] || 0

      message = "**#{index + 1}. #{product.brand_normalized} #{product.original_model}** "
      message += "#{product.width}/#{product.height}R#{product.diameter} #{product.load_index}#{product.speed_index}\n"
      message += "   💰 **#{product.formatted_price}**"

      if suppliers_count > 1
        suppliers_text = @locale == 'uk' ? 'постачальників' : 'поставщиков'
        message += " | 🏪 У #{suppliers_count} #{suppliers_text}"
      end

      if price_savings.positive?
        savings_text = @locale == 'uk' ? 'Економія до' : 'Экономия до'
        message += " | 💸 #{savings_text} #{price_savings} грн"
      end

      message += "\n"
      message += format_product_details(product)
      message += format_reasons(item[:recommendation_reasons])
      message += "\n"
      message
    end

    # Format catalog button with filters
    def format_catalog_button(size_info, season_info)
      size_display = "#{size_info[:width]}/#{size_info[:height]}R#{size_info[:diameter]}"
      season_display = season_display_name(season_info)

      message = "🔍 **#{t('catalog_button_title')}**\n\n"
      message += "📋 #{t('catalog_button_text', size: size_display, season: season_display)}"
      message
    end

    # Get catalog button data structure
    def catalog_button_data(size_info, season_info)
      return nil unless size_info.present? && season_info.present?

      size_display = "#{size_info[:width]}/#{size_info[:height]}R#{size_info[:diameter]}"
      season_display = season_display_name(season_info)

      {
        text: "📋 #{t('catalog_button_text', size: size_display, season: season_display)}",
        filters: {
          width: size_info[:width],
          height: size_info[:height],
          diameter: size_info[:diameter],
          season: season_info
        },
        action: 'apply_catalog_filters'
      }
    end

    # Format continuation options for dialog
    def format_continuation_options
      "🔄 **#{t('continuation_options_title')}**\n\n" \
        "💬 #{t('continue_discussion_option')}\n" \
        "🔍 #{t('new_search_option')}\n\n" \
        "#{t('continuation_prompt')}"
    end

    # Format size guide message
    def format_size_guide
      message = "📏 **#{t('size_guide_title')}**\n\n"
      message += "🔍 #{t('size_guide_how_to_find')}\n\n"
      message += "📋 **#{t('size_guide_explanation_title')}**\n"
      message += "#{t('size_guide_explanation')}\n\n"
      message += "⭐ **#{t('size_guide_popular_title')}**\n"

      popular_tire_sizes.each_with_index do |size, index|
        message += "#{index + 1}. **#{size[:display]}** - #{size[:description]}\n"
      end

      message += "\n🚗 **#{t('size_guide_car_search_title')}**\n"
      message += "#{t('size_guide_car_search_description')}\n\n"
      message += "💬 #{t('size_guide_call_to_action')}"
      message
    end

    # Format brand comparison message
    def format_brand_comparison
      message = "🏷️ **#{t('brand_comparison_title')}**\n\n"
      message += "🎯 #{t('brand_comparison_intro')}\n\n"

      message += "👑 **#{t('brand_comparison_premium_title')}**\n"
      premium_brands.each { |brand| message += format_brand(brand) }
      message += "\n"

      message += "⚖️ **#{t('brand_comparison_middle_title')}**\n"
      middle_segment_brands.each { |brand| message += format_brand(brand) }
      message += "\n"

      message += "💰 **#{t('brand_comparison_budget_title')}**\n"
      budget_brands.each { |brand| message += format_brand(brand) }
      message += "\n"

      message += "📋 **#{t('brand_comparison_recommendations_title')}**\n"
      message += "#{t('brand_comparison_recommendations_text')}\n\n"
      message += "💬 #{t('brand_comparison_call_to_action')}"
      message
    end

    # Get season display name
    def season_display_name(season)
      case season
      when 'winter' then t('season_winter')
      when 'summer' then t('season_summer')
      when 'all_season' then t('season_all_season')
      else season.to_s.capitalize
      end
    end

    # Get price segment display name
    def price_segment_name(segment)
      case segment
      when 'premium' then t('price_segment_premium')
      when 'budget' then t('price_segment_budget')
      when 'middle' then t('price_segment_middle')
      else segment.to_s
      end
    end

    private

    def recommendations_title
      "🎯 **#{t('recommendations_title')}**\n\n"
    end

    def no_results_message
      "😔 #{t('no_results')}"
    end

    def format_recommendation_items(recommendations, _format)
      message = ""
      recommendations.first(5).each_with_index do |item, index|
        product = item[:product]
        score = item[:optimality_score]
        suppliers_count = item[:suppliers_count] || 1
        price_savings = item[:price_savings] || 0

        message += "**#{index + 1}. #{product.brand_normalized} #{product.original_model}** "
        message += "#{product.width}/#{product.height}R#{product.diameter} #{product.load_index}#{product.speed_index}\n"
        message += "   💰 **#{product.formatted_price}** | ⭐ Рейтинг: #{score.round(1)}/10"
        message += " | 🏪 У #{suppliers_count} поставщиков" if suppliers_count > 1
        message += " | 💸 Экономия до #{price_savings} грн" if price_savings.positive?
        message += "\n"
        message += format_product_details(product)
        message += format_reasons(item[:recommendation_reasons])
        message += "\n"
      end
      message
    end

    def format_product_details(product)
      message = ""
      if product.country.present?
        country_name = product.country.respond_to?(:name) ? product.country.name : product.country.to_s
        message += "   🌍 #{country_name} | "
      end
      message += "🏷️ #{product.supplier.name}" if product.supplier.present?
      message += "\n"
      message
    end

    def format_reasons(reasons)
      reasons_list = reasons || ['Доступен в наличии']
      "   ✨ *#{reasons_list.join(', ')}*\n"
    end

    def format_explanation(priority_type)
      message = "\n💡 **#{t('recommendation_explanation_title')}**\n"
      message += "Показаны лучшие предложения для каждой уникальной модели шин. "
      message += "Для каждой модели выбрана самая низкая цена среди всех поставщиков.\n\n"

      case priority_type
      when 'price_quality'
        message += "🎯 **Приоритет: цена/качество** - выбраны модели с лучшим соотношением цены и характеристик."
      when 'prestige'
        message += "🏆 **Приоритет: престиж** - рекомендованы премиум-бренды и топовые модели."
      when 'functionality'
        message += "⚙️ **Приоритет: функциональность** - упор на технические характеристики и эксплуатационные качества."
      else
        message += "⚖️ **Сбалансированный подход** - учтены цена, качество и репутация бренда."
      end

      message += "\n\n"
      message += format_continuation_options
      message
    end

    def format_segment_explanation(price_segment)
      explanation = case price_segment
                    when 'premium' then "💎 #{t('segment_explanation_premium')}"
                    when 'budget' then "💰 #{t('segment_explanation_budget')}"
                    when 'middle' then "⚖️ #{t('segment_explanation_middle')}"
                    else "🔍 #{t('segment_explanation_default')}"
                    end
      "\n💡 **#{explanation}**\n"
    end

    def format_brand(brand)
      "• **#{brand[:name]}** (#{brand[:country]}) - #{brand[:description]}\n"
    end

    def premium_brands
      [
        { name: 'Nokian', country: t('country_finland'), description: t('brand_nokian_desc') },
        { name: 'Michelin', country: t('country_france'), description: t('brand_michelin_desc') },
        { name: 'Continental', country: t('country_germany'), description: t('brand_continental_desc') },
        { name: 'Bridgestone', country: t('country_japan'), description: t('brand_bridgestone_desc') }
      ]
    end

    def middle_segment_brands
      [
        { name: 'Fulda', country: t('country_germany'), description: t('brand_fulda_desc') },
        { name: 'Barum', country: t('country_czech'), description: t('brand_barum_desc') },
        { name: 'Marshal', country: t('country_korea'), description: t('brand_marshal_desc') },
        { name: 'Gislaved', country: t('country_sweden'), description: t('brand_gislaved_desc') }
      ]
    end

    def budget_brands
      [
        { name: 'Росава', country: t('country_ukraine'), description: t('brand_rosava_desc') },
        { name: 'Кама', country: t('country_russia'), description: t('brand_kama_desc') },
        { name: 'Linglong', country: t('country_china'), description: t('brand_linglong_desc') },
        { name: 'Белшина', country: t('country_belarus'), description: t('brand_belshina_desc') }
      ]
    end

    def popular_tire_sizes
      [
        { display: '195/65R15', description: t('size_guide_compact_cars') },
        { display: '205/55R16', description: t('size_guide_standard_cars') },
        { display: '225/60R17', description: t('size_guide_crossovers') },
        { display: '235/55R18', description: t('size_guide_suvs') },
        { display: '175/70R13', description: t('size_guide_small_cars') }
      ]
    end

    # Localization helper
    def t(key, **interpolations)
      message_template = messages[@locale]&.[](key) || messages['ru'][key]
      return key unless message_template

      interpolations.each do |placeholder, value|
        message_template = message_template.gsub("%{#{placeholder}}", value.to_s)
      end

      message_template
    end

    # rubocop:disable Metrics/MethodLength
    def messages
      @messages ||= {
        'ru' => {
          'recommendations_title' => 'Вот мои рекомендации для вас:',
          'recommendation_explanation_title' => 'Почему именно эти шины?',
          'no_results' => 'К сожалению, по вашим критериям не найдено подходящих шин. Попробуйте изменить параметры поиска.',
          'catalog_button_title' => 'Вы можете также просмотреть все размеры:',
          'catalog_button_text' => 'Показать все варианты: %{size} %{season}',
          'continuation_options_title' => 'Что вы хотите сделать дальше?',
          'continue_discussion_option' => '💬 Обсудить эти варианты подробнее',
          'new_search_option' => '🔍 Начать новый поиск с другими параметрами',
          'continuation_prompt' => 'Просто напишите, что вас интересует!',
          'season_winter' => 'Зимние',
          'season_summer' => 'Летние',
          'season_all_season' => 'Всесезонные',
          'price_segment_premium' => 'премиум',
          'price_segment_budget' => 'бюджетные',
          'price_segment_middle' => 'средний ценовой сегмент',
          'segment_explanation_premium' => 'Показаны самые дорогие и качественные модели в данном размере.',
          'segment_explanation_budget' => 'Показаны самые доступные по цене модели в данном размере.',
          'segment_explanation_middle' => 'Показаны модели среднего ценового сегмента с оптимальным соотношением цена/качество.',
          'segment_explanation_default' => 'Показаны подходящие модели в данном размере.',
          'size_guide_title' => 'Как выбрать правильный размер шин?',
          'size_guide_how_to_find' => 'Размер шин указан на боковине покрышки в формате: **195/65R15**',
          'size_guide_explanation_title' => 'Расшифровка размера:',
          'size_guide_explanation' => '• **195** - ширина шины в миллиметрах\n• **65** - высота профиля в % от ширины\n• **R** - радиальная конструкция\n• **15** - диаметр диска в дюймах',
          'size_guide_popular_title' => 'Популярные размеры:',
          'size_guide_compact_cars' => 'компактные автомобили',
          'size_guide_standard_cars' => 'стандартные легковые авто',
          'size_guide_crossovers' => 'кроссоверы и внедорожники',
          'size_guide_suvs' => 'большие внедорожники',
          'size_guide_small_cars' => 'малолитражки',
          'size_guide_car_search_title' => 'Не знаете размер?',
          'size_guide_car_search_description' => 'Укажите марку и модель вашего автомобиля, и я помогу найти подходящий размер шин.',
          'size_guide_call_to_action' => 'Введите размер шин или марку автомобиля, чтобы начать подбор!',
          'brand_comparison_title' => 'Сравнение брендов шин',
          'brand_comparison_intro' => 'Выбор бренда напрямую влияет на качество, безопасность и срок службы шин. Вот основные категории:',
          'brand_comparison_premium_title' => 'Премиум сегмент (высший класс)',
          'brand_comparison_middle_title' => 'Средний сегмент (оптимальное соотношение)',
          'brand_comparison_budget_title' => 'Бюджетный сегмент (доступные цены)',
          'brand_comparison_recommendations_title' => 'Как выбрать?',
          'brand_comparison_recommendations_text' => "• **Для максимальной безопасности** → Премиум бренды\n• **Для ежедневного использования** → Средний сегмент\n• **Для экономии бюджета** → Бюджетные бренды\n• **Для зимы** → Nokian, Continental, Gislaved\n• **Для спорта** → Michelin, Bridgestone\n• **Для города** → Barum, Marshal, Fulda",
          'brand_comparison_call_to_action' => 'Назовите ваш бюджет и потребности, и я подберу оптимальный бренд!',
          'country_finland' => 'Финляндия',
          'country_france' => 'Франция',
          'country_germany' => 'Германия',
          'country_japan' => 'Япония',
          'country_czech' => 'Чехия',
          'country_korea' => 'Корея',
          'country_sweden' => 'Швеция',
          'country_ukraine' => 'Украина',
          'country_russia' => 'Россия',
          'country_china' => 'Китай',
          'country_belarus' => 'Беларусь',
          'brand_nokian_desc' => 'Лидер зимних шин, превосходное качество',
          'brand_michelin_desc' => 'Инновации и долговечность',
          'brand_continental_desc' => 'Немецкое качество и технологии',
          'brand_bridgestone_desc' => 'Спортивные и премиум шины',
          'brand_fulda_desc' => 'Качественные шины по разумной цене',
          'brand_barum_desc' => 'Надежность и комфорт',
          'brand_marshal_desc' => 'Современные технологии, доступные цены',
          'brand_gislaved_desc' => 'Отличные зимние шины',
          'brand_rosava_desc' => 'Украинское производство, хорошее качество',
          'brand_kama_desc' => 'Российский производитель, доступные цены',
          'brand_linglong_desc' => 'Китайские шины с улучшенным качеством',
          'brand_belshina_desc' => 'Белорусские шины, надежность'
        },
        'uk' => {
          'recommendations_title' => 'Ось мої рекомендації для вас:',
          'recommendation_explanation_title' => 'Чому саме ці шини?',
          'no_results' => 'На жаль, за вашими критеріями не знайдено підходящих шин. Спробуйте змінити параметри пошуку.',
          'catalog_button_title' => 'Ви можете також переглянути всі розміри:',
          'catalog_button_text' => 'Показати всі варіанти: %{size} %{season}',
          'continuation_options_title' => 'Що ви хочете зробити далі?',
          'continue_discussion_option' => '💬 Обговорити ці варіанти детальніше',
          'new_search_option' => '🔍 Почати новий пошук з іншими параметрами',
          'continuation_prompt' => 'Просто напишіть, що вас цікавить!',
          'season_winter' => 'Зимові',
          'season_summer' => 'Літні',
          'season_all_season' => 'Всесезонні',
          'price_segment_premium' => 'преміум',
          'price_segment_budget' => 'бюджетні',
          'price_segment_middle' => 'середній ціновий сегмент',
          'segment_explanation_premium' => 'Показані найдорожчі та якісні моделі в даному розмірі.',
          'segment_explanation_budget' => 'Показані найдоступніші за ціною моделі в даному розмірі.',
          'segment_explanation_middle' => 'Показані моделі середнього цінового сегменту з оптимальним співвідношенням ціна/якість.',
          'segment_explanation_default' => 'Показані підходящі моделі в даному розмірі.',
          'size_guide_title' => 'Як обрати правильний розмір шин?',
          'size_guide_how_to_find' => 'Розмір шин вказаний на боковині покришки у форматі: **195/65R15**',
          'size_guide_explanation_title' => 'Розшифровка розміру:',
          'size_guide_explanation' => '• **195** - ширина шини в міліметрах\n• **65** - висота профілю в % від ширини\n• **R** - радіальна конструкція\n• **15** - діаметр диска в дюймах',
          'size_guide_popular_title' => 'Популярні розміри:',
          'size_guide_compact_cars' => 'компактні автомобілі',
          'size_guide_standard_cars' => 'стандартні легкові авто',
          'size_guide_crossovers' => 'кросовери та позашляховики',
          'size_guide_suvs' => 'великі позашляховики',
          'size_guide_small_cars' => 'малолітражки',
          'size_guide_car_search_title' => 'Не знаєте розмір?',
          'size_guide_car_search_description' => 'Вкажіть марку та модель вашого автомобіля, і я допоможу знайти підходящий розмір шин.',
          'size_guide_call_to_action' => 'Введіть розмір шин або марку автомобіля, щоб почати підбір!',
          'brand_comparison_title' => 'Порівняння брендів шин',
          'brand_comparison_intro' => 'Вибір бренду безпосередньо впливає на якість, безпеку та термін служби шин. Ось основні категорії:',
          'brand_comparison_premium_title' => 'Преміум сегмент (вищий клас)',
          'brand_comparison_middle_title' => 'Середній сегмент (оптимальне співвідношення)',
          'brand_comparison_budget_title' => 'Бюджетний сегмент (доступні ціни)',
          'brand_comparison_recommendations_title' => 'Як обрати?',
          'brand_comparison_recommendations_text' => "• **Для максимальної безпеки** → Преміум бренди\n• **Для щоденного використання** → Середній сегмент\n• **Для економії бюджету** → Бюджетні бренди\n• **Для зими** → Nokian, Continental, Gislaved\n• **Для спорту** → Michelin, Bridgestone\n• **Для міста** → Barum, Marshal, Fulda",
          'brand_comparison_call_to_action' => 'Назвіть ваш бюджет та потреби, і я підберу оптимальний бренд!',
          'country_finland' => 'Фінляндія',
          'country_france' => 'Франція',
          'country_germany' => 'Німеччина',
          'country_japan' => 'Японія',
          'country_czech' => 'Чехія',
          'country_korea' => 'Корея',
          'country_sweden' => 'Швеція',
          'country_ukraine' => 'Україна',
          'country_russia' => 'Росія',
          'country_china' => 'Китай',
          'country_belarus' => 'Білорусь',
          'brand_nokian_desc' => 'Лідер зимових шин, відмінна якість',
          'brand_michelin_desc' => 'Інновації та довговічність',
          'brand_continental_desc' => 'Німецька якість та технології',
          'brand_bridgestone_desc' => 'Спортивні та преміум шини',
          'brand_fulda_desc' => 'Якісні шини за розумною ціною',
          'brand_barum_desc' => 'Надійність та комфорт',
          'brand_marshal_desc' => 'Сучасні технології, доступні ціни',
          'brand_gislaved_desc' => 'Відмінні зимові шини',
          'brand_rosava_desc' => 'Українське виробництво, хороша якість',
          'brand_kama_desc' => 'Російський виробник, доступні ціни',
          'brand_linglong_desc' => 'Китайські шини з покращеною якістю',
          'brand_belshina_desc' => 'Білоруські шини, надійність'
        }
      }
    end
    # rubocop:enable Metrics/MethodLength

    # Generate follow-up suggestions based on context
    # @param action [String] Response action type
    # @param has_recommendations [Boolean] Whether response contains recommendations
    # @param current_filters [Hash] Current search filters
    # @return [Array<Hash>] Suggestions array
    def generate_suggestions(action, has_recommendations: false, current_filters: {})
      suggestions = []

      texts = suggestion_texts

      # Based on action, generate relevant suggestions
      if has_recommendations
        suggestions << { id: 'compare', text: texts[:compare_brands], type: 'comparison' }
        suggestions << { id: 'details', text: texts[:more_details], type: 'detail' }
        suggestions << { id: 'catalog', text: texts[:view_catalog], type: 'action' }
      end

      case action
      when 'show_recommendations', 'show_recommendations_with_options'
        suggestions << { id: 'budget', text: texts[:show_budget], type: 'filter' }
        suggestions << { id: 'premium', text: texts[:show_premium], type: 'filter' }
      when 'size_guide_shown', 'no_results'
        suggestions << { id: 'winter', text: texts[:show_winter], type: 'filter' }
        suggestions << { id: 'summer', text: texts[:show_summer], type: 'filter' }
        suggestions << { id: 'other_size', text: texts[:other_size], type: 'filter' }
      when 'fallback', 'error'
        suggestions << { id: 'change_filters', text: texts[:change_filters], type: 'filter' }
        suggestions << { id: 'ask_expert', text: texts[:ask_expert], type: 'action' }
      when 'show_car_search_button'
        suggestions << { id: 'enter_size', text: texts[:enter_size], type: 'filter' }
        suggestions << { id: 'winter', text: texts[:show_winter], type: 'filter' }
        suggestions << { id: 'summer', text: texts[:show_summer], type: 'filter' }
      when 'brand_comparison_shown'
        suggestions << { id: 'premium', text: texts[:show_premium], type: 'filter' }
        suggestions << { id: 'budget', text: texts[:show_budget], type: 'filter' }
      end

      # Add seasonal suggestions if season not set
      if current_filters[:season].blank? && suggestions.size < 4
        suggestions << { id: 'winter', text: texts[:show_winter], type: 'filter' } unless suggestions.any? { |s| s[:id] == 'winter' }
        suggestions << { id: 'summer', text: texts[:show_summer], type: 'filter' } unless suggestions.any? { |s| s[:id] == 'summer' }
      end

      suggestions.first(4)
    end

    private

    def suggestion_texts
      if @locale == 'uk'
        {
          show_winter: 'Зимові варіанти',
          show_summer: 'Літні варіанти',
          show_budget: 'Бюджетні варіанти',
          show_premium: 'Преміум варіанти',
          compare_brands: 'Порівняти бренди',
          more_details: 'Детальніше про ці шини',
          other_size: 'Інший розмір',
          view_catalog: 'Переглянути в каталозі',
          change_filters: 'Змінити параметри',
          ask_expert: 'Запитати експерта',
          enter_size: 'Ввести розмір вручну'
        }
      else
        {
          show_winter: 'Зимние варианты',
          show_summer: 'Летние варианты',
          show_budget: 'Бюджетные варианты',
          show_premium: 'Премиум варианты',
          compare_brands: 'Сравнить бренды',
          more_details: 'Подробнее об этих шинах',
          other_size: 'Другой размер',
          view_catalog: 'Смотреть в каталоге',
          change_filters: 'Изменить параметры',
          ask_expert: 'Спросить эксперта',
          enter_size: 'Ввести размер вручную'
        }
      end
    end
  end
end
