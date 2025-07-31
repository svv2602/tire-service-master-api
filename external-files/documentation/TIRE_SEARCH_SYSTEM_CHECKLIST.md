# 🔍 ПЛАН-ЧЕКЛИСТ: СИСТЕМА ГИБРИДНОГО ПОИСКА ШИН

## 🎯 **ЦЕЛЬ ПРОЕКТА**
Создать интеллектуальную систему поиска шин с поддержкой естественных запросов пользователей типа "Шины на БМВ 320 2019 года на 17" или "резина для тигуана".

---

## 📊 **ЭТАП 1: ПОДГОТОВКА ДАННЫХ И ИНФРАСТРУКТУРА**

### **Backend (tire-service-master-api)**

#### 🗄️ **1.1 Создание новых таблиц и моделей**
- [ ] **Миграция: car_tire_configurations** 
  - [ ] Поля: brand_id, model_id, year_from, year_to, tire_sizes (JSON), search_aliases (JSON), search_tokens (TEXT)
  - [ ] Индексы: GIN на tire_sizes и search_tokens, составной на brand_id+model_id
  - [ ] Файл: `db/migrate/xxx_create_car_tire_configurations.rb`

- [ ] **Миграция: tire_data_versions**
  - [ ] Поля: version, source_description, file_checksums (JSON), statistics (JSON), imported_at, is_active
  - [ ] Уникальный индекс на version
  - [ ] Файл: `db/migrate/xxx_create_tire_data_versions.rb`

- [ ] **Модель: CarTireConfiguration**
  - [ ] Связи с CarBrand и CarModel
  - [ ] Скоупы: search_by_query, with_diameter, for_year
  - [ ] Валидации и методы поиска
  - [ ] Файл: `app/models/car_tire_configuration.rb`

- [ ] **Модель: TireDataVersion**
  - [ ] Методы версионирования и статистики
  - [ ] Валидации версий
  - [ ] Файл: `app/models/tire_data_version.rb`

#### 🔧 **1.2 Сервисы обработки данных**
- [ ] **TireSearchService**
  - [ ] Гибридный парсинг запросов (простой + LLM)
  - [ ] Константы алиасов брендов и моделей
  - [ ] Интеграция с OpenAI API
  - [ ] Файл: `app/services/tire_search_service.rb`

- [ ] **TireData::Processor**
  - [ ] Обработка CSV файлов
  - [ ] Инкрементальное обновление
  - [ ] Версионирование данных
  - [ ] Файл: `lib/tire_data/processor.rb`

- [ ] **TireData::Migrator**
  - [ ] Конвертация CSV в агрегированные данные
  - [ ] Создание алиасов и токенов поиска
  - [ ] Файл: `lib/tire_data/migrator.rb`

#### 🌐 **1.3 API контроллеры**
- [ ] **TireSearchController**
  - [ ] POST /api/v1/tire_search - основной поиск
  - [ ] GET /api/v1/tire_search/suggestions - автодополнение
  - [ ] Кеширование популярных запросов
  - [ ] Файл: `app/controllers/api/v1/tire_search_controller.rb`

- [ ] **TireDataController (админский)**
  - [ ] GET /api/v1/admin/tire_data/versions - список версий
  - [ ] POST /api/v1/admin/tire_data/update - обновление данных
  - [ ] DELETE /api/v1/admin/tire_data/rollback - откат версии
  - [ ] Файл: `app/controllers/api/v1/admin/tire_data_controller.rb`

#### ⚙️ **1.4 Rake задачи**
- [ ] **tire_data:update** - обновление данных из CSV
- [ ] **tire_data:rollback** - откат к предыдущей версии
- [ ] **tire_data:versions** - просмотр версий
- [ ] **tire_data:cleanup** - очистка старых данных
- [ ] **tire_data:generate_seeds** - генерация seeds файлов
- [ ] Файл: `lib/tasks/tire_data_management.rake`

#### 📝 **1.5 Seeds файлы**
- [ ] **tire_brands_processed.rb** - обработанные бренды
- [ ] **tire_models_processed.rb** - обработанные модели  
- [ ] **tire_configurations_base.rb** - базовые конфигурации
- [ ] **tire_search_aliases.rb** - алиасы для поиска
- [ ] Папка: `db/seeds/`

---

## 🖥️ **ЭТАП 2: FRONTEND ИНТЕГРАЦИЯ**

### **Frontend (tire-service-master-web)**

#### 🔌 **2.1 API интеграция**
- [ ] **tireSearch.api.ts**
  - [ ] searchTires mutation
  - [ ] getTireSuggestions query
  - [ ] Типизация запросов и ответов
  - [ ] Файл: `src/api/tireSearch.api.ts`

- [ ] **Типы TypeScript**
  - [ ] TireSearchQuery interface
  - [ ] TireSearchResult interface
  - [ ] TireConfiguration interface
  - [ ] Файл: `src/types/tireSearch.ts`

#### 🎨 **2.2 UI компоненты**
- [ ] **TireSearchBar**
  - [ ] Поле ввода с автодополнением
  - [ ] Обработка естественных запросов
  - [ ] Подсказки для пользователя
  - [ ] Файл: `src/components/tire-search/TireSearchBar.tsx`

- [ ] **TireSearchResults**
  - [ ] Отображение результатов поиска
  - [ ] Фильтрация по диаметру, типу шин
  - [ ] Сортировка по релевантности
  - [ ] Файл: `src/components/tire-search/TireSearchResults.tsx`

- [ ] **TireConfigurationCard**
  - [ ] Карточка конфигурации шин
  - [ ] Отображение размеров, годов
  - [ ] Кнопки действий
  - [ ] Файл: `src/components/tire-search/TireConfigurationCard.tsx`

#### 📱 **2.3 Страницы**
- [ ] **TireSearchPage**
  - [ ] Главная страница поиска шин
  - [ ] Интеграция всех компонентов
  - [ ] Роутинг /tire-search
  - [ ] Файл: `src/pages/tire-search/TireSearchPage.tsx`

- [ ] **TireSearchAdminPage**
  - [ ] Админская панель управления данными
  - [ ] Просмотр версий, обновление
  - [ ] Статистика поиска
  - [ ] Файл: `src/pages/admin/tire-search/TireSearchAdminPage.tsx`

#### 🎯 **2.4 Хуки и утилиты**
- [ ] **useTireSearch**
  - [ ] Хук для работы с поиском
  - [ ] Кеширование результатов
  - [ ] Файл: `src/hooks/useTireSearch.ts`

- [ ] **tireSearchUtils**
  - [ ] Утилиты парсинга запросов
  - [ ] Форматирование результатов
  - [ ] Файл: `src/utils/tireSearchUtils.ts`

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

#### ⚙️ **4.1 Конфигурация**
- [ ] **Environment переменные**
  - [ ] OPENAI_API_KEY для LLM
  - [ ] TIRE_SEARCH_CACHE_TTL
  - [ ] Файл: `.env.example`

- [ ] **Redis конфигурация**
  - [ ] Кеширование поисковых запросов
  - [ ] Настройка TTL
  - [ ] Файл: `config/redis.yml`

#### 📈 **4.2 Мониторинг и аналитика**
- [ ] **TireSearchAnalytics**
  - [ ] Отслеживание популярных запросов
  - [ ] Статистика использования
  - [ ] Файл: `app/services/tire_search_analytics.rb`

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