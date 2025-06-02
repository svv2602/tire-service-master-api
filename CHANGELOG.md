# Changelog

## [Unreleased] - 2024-12-19

### Fixed
- **Налоговый номер партнера теперь необязателен**
  - Убрана валидация `presence: true` для поля `tax_number` в модели `Partner`
  - Добавлена валидация `allow_blank: true` - поле может быть пустым
  - Если налоговый номер указан, он все еще должен быть уникальным
  - Обновлена документация API с указанием обязательных и необязательных полей
  - Исправлена форма создания партнера на фронтенде
  - Улучшена обработка ошибок API

### Technical Changes
- Модель `Partner`: изменена валидация с `validates :tax_number, presence: true, uniqueness: true` на `validates :tax_number, uniqueness: true, allow_blank: true`
- Фронтенд: убран атрибут `required` из поля налогового номера
- Документация: добавлены разделы с обязательными и необязательными полями для API создания партнера

### API Changes
- `POST /api/v1/partners` - поле `partner.tax_number` теперь необязательно

--- 