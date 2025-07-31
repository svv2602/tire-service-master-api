# 🔍 ПЛАН-ЧЕКЛИСТ: СИСТЕМА ГИБРИДНОГО ПОИСКА ШИН

## 🎯 **ЦЕЛЬ ПРОЕКТА**
Создать интеллектуальную систему поиска шин с поддержкой естественных запросов пользователей типа "Шины на БМВ 320 2019 года на 17" или "резина для тигуана".

---

## 📊 **ЭТАП 1: ПОДГОТОВКА ДАННЫХ И ИНФРАСТРУКТУРА** ✅ **ЗАВЕРШЕНО**

### **Backend (tire-service-master-api)**

#### 🗄️ **1.1 Создание новых таблиц и моделей** ✅ **ЗАВЕРШЕНО**
- [x] **Миграция: car_tire_configurations** ✅
  - [x] Поля: brand_id, model_id, year_from, year_to, tire_sizes (JSONB), search_aliases (JSONB), search_tokens (TEXT)
  - [x] Индексы: GIN на tire_sizes и search_tokens, составной на brand_id+model_id
  - [x] Файл: `db/migrate/20250731095048_create_car_tire_configurations.rb`

- [x] **Миграция: tire_data_versions** ✅
  - [x] Поля: version, source_description, file_checksums (JSONB), statistics (JSONB), imported_at, is_active
  - [x] Уникальный индекс на version
  - [x] Файл: `db/migrate/20250731095113_create_tire_data_versions.rb`

- [x] **Модель: CarTireConfiguration** ✅
  - [x] Связи с CarBrand и CarModel
  - [x] Скоупы: search_by_query, with_diameter, for_year, for_brand, for_model, by_relevance
  - [x] Валидации и методы поиска (search_with_filters, update_search_tokens!)
  - [x] Файл: `app/models/car_tire_configuration.rb`

- [x] **Модель: TireDataVersion** ✅
  - [x] Методы версионирования и статистики (activate!, rollback_to_version!, cleanup_old_versions!)
  - [x] Валидации версий
  - [x] Файл: `app/models/tire_data_version.rb`

#### 🔧 **1.2 Сервисы обработки данных** ✅ **ЗАВЕРШЕНО**
- [x] **TireSearchService** ✅ **ЗАВЕРШЕНО**
  - [x] Гибридный парсинг запросов (простой + LLM заглушка)
  - [x] Константы алиасов брендов и моделей (BMW/БМВ, VW/Фольксваген, 3 Series/тройка)
  - [x] Интеграция с OpenAI API (заглушка для будущего развития)
  - [x] Файл: `app/services/tire_search_service.rb`

- [x] **TireData::Processor** ✅ **ЗАВЕРШЕНО**
  - [x] Обработка CSV файлов с валидацией и очисткой данных
  - [x] Инкрементальное обновление по чексуммам файлов
  - [x] Версионирование данных с резервным копированием
  - [x] Агрегация по диапазонам лет и объединение размеров шин
  - [x] Файл: `lib/tire_data/processor.rb`

- [x] **TireData::Migrator** ✅ **ЗАВЕРШЕНО**
  - [x] Конвертация CSV в агрегированные данные
  - [x] Создание алиасов и токенов поиска
  - [x] Генерация seed файлов (brands, models, configurations, aliases)
  - [x] Поддержка образцов данных для тестирования
  - [x] Файл: `lib/tire_data/migrator.rb`

#### 🌐 **1.3 API контроллеры** ✅ **ЗАВЕРШЕНО**
- [x] **TireSearchController** ✅
  - [x] POST /api/v1/tire_search - основной поиск
  - [x] GET /api/v1/tire_search/suggestions - автодополнение
  - [x] GET /api/v1/tire_search/popular - популярные запросы
  - [x] GET /api/v1/tire_search/brands - список брендов
  - [x] GET /api/v1/tire_search/models - модели авто
  - [x] GET /api/v1/tire_search/diameters - доступные диаметры
  - [x] GET /api/v1/tire_search/statistics - статистика (админы)
  - [x] Кеширование популярных запросов (Redis, 1 час)
  - [x] Файл: `app/controllers/api/v1/tire_search_controller.rb`

- [x] **TireDataController (админский)** ✅ **ЗАВЕРШЕНО**
  - [x] GET /api/v1/admin/tire_data/versions - список версий
  - [x] GET /api/v1/admin/tire_data/current_version - текущая версия
  - [x] POST /api/v1/admin/tire_data/update - обновление данных
  - [x] DELETE /api/v1/admin/tire_data/rollback - откат версии
  - [x] GET /api/v1/admin/tire_data/statistics - детальная статистика
  - [x] POST /api/v1/admin/tire_data/cleanup - очистка старых версий
  - [x] Файл: `app/controllers/api/v1/admin/tire_data_controller.rb`

#### ⚙️ **1.4 Rake задачи** ✅ **ЗАВЕРШЕНО**
- [x] **tire_data:update** - обновление данных из CSV с версионированием ✅
- [x] **tire_data:migrate** - миграция CSV в seed файлы ✅
- [x] **tire_data:rollback** - откат к предыдущей версии ✅
- [x] **tire_data:versions** - просмотр версий с детальной статистикой ✅
- [x] **tire_data:cleanup** - очистка старых данных ✅
- [x] **tire_data:generate_seeds** - генерация seeds из текущих данных ✅
- [x] **tire_data:validate** - проверка целостности данных ✅
- [x] **tire_data:search_stats** - статистика системы поиска ✅
- [x] Файл: `lib/tasks/tire_data_management.rake`

#### 📝 **1.5 Seeds файлы** ✅ **ЗАВЕРШЕНО**
- [x] **tire_configurations_test.rb** - тестовые конфигурации ✅  
  - [x] 6 конфигураций (BMW, Mercedes, Volkswagen)
  - [x] Штатные и опциональные размеры шин
  - [x] Поисковые алиасы на русском языке
- [x] **tire_brands_processed.rb** - обработанные бренды (47 брендов с алиасами) ✅
- [x] **tire_models_processed.rb** - обработанные модели (130+ моделей с алиасами) ✅  
- [x] **tire_configurations_full.rb** - полные конфигурации (20+ популярных моделей) ✅
- [x] **tire_search_aliases.rb** - расширенные алиасы для поиска ✅
- [x] Папка: `db/seeds/` ✅

---

## 🖥️ **ЭТАП 2: FRONTEND ИНТЕГРАЦИЯ** ✅ **ЗАВЕРШЕНО**

### **Frontend (tire-service-master-web)**

#### 🔌 **2.1 API интеграция** ✅ **ЗАВЕРШЕНО**
- [x] **tireSearch.api.ts** ✅
  - [x] searchTires mutation ✅
  - [x] getTireSuggestions query ✅
  - [x] Типизация запросов и ответов ✅
  - [x] Файл: `src/api/tireSearch.api.ts` ✅

- [x] **Типы TypeScript** ✅
  - [x] TireSearchQuery interface ✅
  - [x] TireSearchResult interface ✅
  - [x] TireConfiguration interface ✅
  - [x] TireSearchFilters interface ✅
  - [x] Файл: `src/types/tireSearch.ts` ✅

#### 🎨 **2.2 UI компоненты** ✅ **ЗАВЕРШЕНО**
- [x] **TireSearchBar** ✅
  - [x] Поле ввода с автодополнением ✅
  - [x] Обработка естественных запросов ✅
  - [x] Подсказки для пользователя ✅
  - [x] Debounce и кеширование ✅
  - [x] Файл: `src/components/tire-search/TireSearchBar.tsx` ✅

- [x] **TireSearchResults** ✅
  - [x] Отображение результатов поиска ✅
  - [x] Фильтрация по диаметру, типу шин ✅
  - [x] Сортировка по релевантности ✅
  - [x] Пагинация и состояния загрузки ✅
  - [x] Файл: `src/components/tire-search/TireSearchResults.tsx` ✅

- [x] **TireConfigurationCard** ✅
  - [x] Карточка конфигурации шин ✅
  - [x] Отображение размеров, годов ✅
  - [x] Кнопки действий и избранное ✅
  - [x] Адаптивный дизайн ✅
  - [x] Файл: `src/components/tire-search/TireConfigurationCard.tsx` ✅

- [x] **SearchHistory, PopularSearches, SearchSuggestions** ✅
  - [x] История поиска с localStorage ✅
  - [x] Популярные запросы с трендами ✅
  - [x] Автодополнение с подсветкой ✅
  - [x] Файлы: `src/components/tire-search/` ✅

#### 📱 **2.3 Страницы** ✅ **ЗАВЕРШЕНО**
- [x] **TireSearchPage** ✅
  - [x] Главная страница поиска шин ✅
  - [x] Интеграция всех компонентов ✅
  - [x] Роутинг /client/tire-search ✅
  - [x] URL синхронизация и SEO ✅
  - [x] Файл: `src/pages/tire-search/TireSearchPage.tsx` ✅

- [x] **TireDataManagementPage** ✅
  - [x] Админская панель управления данными ✅
  - [x] Просмотр версий, обновление ✅
  - [x] Статистика поиска ✅
  - [x] Файл: `src/pages/admin/tire-search/TireDataManagementPage.tsx` ✅

#### 🎯 **2.4 Хуки и утилиты** ✅ **ЗАВЕРШЕНО**
- [x] **useTireSearch** ✅
  - [x] Хук для работы с поиском ✅
  - [x] Кеширование результатов ✅
  - [x] История и избранное ✅
  - [x] Файл: `src/hooks/useTireSearch.ts` ✅

- [x] **Локализация** ✅
  - [x] Полная локализация RU/UK ✅
  - [x] 150+ ключей перевода ✅
  - [x] Файлы: `src/i18n/locales/tire-search/` ✅

---

## 🧪 **ЭТАП 3: ТЕСТИРОВАНИЕ И ОТЛАДКА**

#### 🔍 **3.1 Backend тестирование**
- [ ] **Модульные тесты**
  - [ ] TireSearchService spec
  - [ ] CarTireConfiguration model spec
  - [ ] TireData::Processor spec
  - [ ] Папка: `spec/services/`, `spec/models/`

- [ ] **Интеграционные тесты**
  - [ ] API endpoints тестирование
  - [ ] Полный цикл поиска
  - [ ] Файл: `spec/integration/tire_search_spec.rb`

- [ ] **Тестовые данные**
  - [ ] Фикстуры для тестирования
  - [ ] Примеры запросов
  - [ ] Папка: `spec/fixtures/tire_data/`

#### 🎭 **3.2 Frontend тестирование**
- [ ] **Компонентные тесты**
  - [ ] TireSearchBar.test.tsx
  - [ ] TireSearchResults.test.tsx
  - [ ] Папка: `src/components/__tests__/`

- [ ] **E2E тестирование**
  - [ ] Полный поиск шин
  - [ ] Различные типы запросов
  - [ ] Файл: `cypress/e2e/tire-search.cy.ts`

#### 📊 **3.3 Тестовые HTML файлы**
- [ ] **test_tire_search_basic.html** - базовый поиск
- [ ] **test_tire_search_natural.html** - естественные запросы
- [ ] **test_tire_search_admin.html** - админские функции
- [ ] Папка: `external-files/testing/`

---

## 🚀 **ЭТАП 4: РАЗВЕРТЫВАНИЕ И ОПТИМИЗАЦИЯ**

#### ⚙️ **4.1 Конфигурация** ✅ **ЗАВЕРШЕНО**
- [x] **Environment переменные через админку** ✅
  - [x] OPENAI_API_KEY для LLM ✅
  - [x] TIRE_SEARCH_CACHE_TTL ✅
  - [x] REDIS_URL конфигурация ✅
  - [x] Админская страница настроек ✅
  - [x] Файл: `app/controllers/api/v1/admin/system_settings_controller.rb` ✅

- [x] **Redis конфигурация** ✅
  - [x] Кеширование поисковых запросов ✅
  - [x] Настройка TTL через админку ✅
  - [x] Автоматическое подключение ✅

#### 📈 **4.2 Мониторинг и аналитика** ✅ **ЗАВЕРШЕНО**
- [x] **TireSearchAnalytics** ✅
  - [x] Отслеживание популярных запросов ✅
  - [x] Статистика использования ✅
  - [x] Экспорт и очистка данных ✅
  - [x] Redis интеграция ✅
  - [x] Файл: `app/services/tire_search_analytics.rb` ✅

- [ ] **Логирование**
  - [ ] Структурированные логи поиска
  - [ ] Мониторинг производительности
  - [ ] Конфигурация: `config/logging.rb`

#### 🔄 **4.3 CI/CD пайплайн**
- [ ] **GitHub Actions**
  - [ ] Автоматическое тестирование
  - [ ] Деплой в staging/production
  - [ ] Файл: `.github/workflows/tire-search-deploy.yml`

---

## 📚 **ЭТАП 5: ДОКУМЕНТАЦИЯ И ОБУЧЕНИЕ**

#### 📖 **5.1 Техническая документация**
- [ ] **API документация**
  - [ ] Swagger/OpenAPI спецификация
  - [ ] Примеры запросов и ответов
  - [ ] Файл: `swagger/tire_search_api.yml`

- [ ] **Руководство разработчика**
  - [ ] Архитектура системы
  - [ ] Процесс обновления данных
  - [ ] Файл: `docs/TIRE_SEARCH_DEVELOPER_GUIDE.md`

#### 👥 **5.2 Пользовательская документация**
- [ ] **Руководство пользователя**
  - [ ] Как искать шины
  - [ ] Примеры запросов
  - [ ] Файл: `docs/TIRE_SEARCH_USER_GUIDE.md`

- [ ] **Админское руководство**
  - [ ] Управление данными
  - [ ] Обновление версий
  - [ ] Файл: `docs/TIRE_SEARCH_ADMIN_GUIDE.md`

---

## ✅ **КРИТЕРИИ ГОТОВНОСТИ**

### **Функциональные требования:**
- [ ] Поиск по естественным запросам работает
- [ ] Поддержка украинского и русского языков
- [ ] Автодополнение и подсказки
- [ ] Админская панель управления данными
- [ ] Версионирование и откат данных

### **Нефункциональные требования:**
- [ ] Время ответа < 500мс для 95% запросов
- [ ] Поддержка 1000+ одновременных пользователей
- [ ] Покрытие тестами > 80%
- [ ] Документация готова
- [ ] CI/CD настроен

### **Качество кода:**
- [ ] Код проходит линтинг
- [ ] Все тесты проходят
- [ ] Code review выполнен
- [ ] Безопасность проверена

---

## 📅 **ВРЕМЕННЫЕ РАМКИ**

| Этап | Время | Ответственный |
|------|-------|---------------|
| Этап 1: Backend инфраструктура | 3-4 дня | Backend Dev |
| Этап 2: Frontend интеграция | 2-3 дня | Frontend Dev |
| Этап 3: Тестирование | 1-2 дня | QA + Dev |
| Этап 4: Развертывание | 1 день | DevOps |
| Этап 5: Документация | 1 день | Tech Writer |

**Общее время: 8-11 дней**

---

## 🎯 **СЛЕДУЮЩИЕ ШАГИ**

1. ✅ Создать ветки feature/tire-search-system
2. 🔄 Начать с Этапа 1.1 - создание миграций
3. 📝 Регулярно обновлять чеклист
4. 🔍 Проводить code review на каждом этапе
5. 🚀 Тестировать функциональность по мере разработки

---

**Автор:** AI Assistant  
**Дата создания:** $(date)  
**Версия:** 1.0  
**Статус:** В разработке