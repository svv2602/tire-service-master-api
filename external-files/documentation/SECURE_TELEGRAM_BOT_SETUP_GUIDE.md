# 🤖 Руководство по созданию безопасного Telegram бота

## 🚨 ВНИМАНИЕ: Старый бот скомпрометирован!

Ваш текущий бот получал спам-сообщения из-за небезопасной настройки. **ОБЯЗАТЕЛЬНО создайте нового бота!**

## 📋 ПОШАГОВОЕ СОЗДАНИЕ НОВОГО БОТА

### Шаг 1: Отзыв старого токена

1. Откройте Telegram и найдите **@BotFather**
2. Отправьте команду `/mybots`
3. Выберите **@tire_service_ua_bot**
4. Нажмите ⋮ → API Token → Revoke token (или используйте команду /token).
5. Подтвердите создание нового токена — старый автоматически станет недействительным.

ИЛИ 

### Шаг 2: Создание нового бота

1. У **@BotFather** отправьте `/newbot`
2. Введите имя бота: `Tire Service Bot New`
3. Введите username: `tire_service_new_bot` (или другой доступный)
4. **СОХРАНИТЕ НОВЫЙ ТОКЕН В БЕЗОПАСНОМ МЕСТЕ!**

### Шаг 3: Настройка нового бота

```bash
# У @BotFather выполните:
/setdescription - Бот для управления записями в шиномонтаж
/setabouttext - Официальный бот сервиса Tire Service
/setuserpic - Загрузите логотип компании
```

## 🔒 БЕЗОПАСНАЯ НАСТРОЙКА В СИСТЕМЕ

### 1. Обновление переменных окружения

Создайте файл `.env` (НЕ коммитьте в git!):
```bash
# Новый безопасный токен
TELEGRAM_BOT_TOKEN=новый_токен_от_BotFather

# Секретный ключ для webhook (сгенерируйте случайную строку)
TELEGRAM_WEBHOOK_SECRET=ваш_секретный_ключ_32_символа

# Безопасный домен (НЕ ngrok!)
TELEGRAM_WEBHOOK_URL=https://yourdomain.com/api/v1/telegram_webhook

# Admin Chat ID (получите после настройки)
TELEGRAM_ADMIN_CHAT_ID=ваш_chat_id
```

### 2. Генерация секретного ключа

```bash
# Сгенерируйте случайный ключ
openssl rand -base64 32
```

### 3. Обновление настроек в админке

1. Откройте `/admin/notifications/telegram`
2. Введите новый токен бота
3. **НЕ устанавливайте webhook через ngrok!**
4. Включите тестовый режим
5. Сохраните настройки

## 🛡️ БЕЗОПАСНАЯ НАСТРОЙКА WEBHOOK

### ❌ НЕПРАВИЛЬНО (как было):
```
Webhook URL: https://877e149de4f1.ngrok-free.app/api/v1/telegram_webhook
Secret Token: отсутствует
Защита: отсутствует
```

### ✅ ПРАВИЛЬНО (как должно быть):
```
Webhook URL: https://yourdomain.com/api/v1/telegram_webhook  
Secret Token: случайная строка 32 символа
SSL: обязательно
IP ограничения: только Telegram серверы
```

### Настройка защищенного webhook:

1. **Получите SSL сертификат для домена**
2. **Настройте nginx с SSL**
3. **Добавьте проверку Secret Token в код:**

```ruby
# app/controllers/api/v1/telegram_webhook_controller.rb
class Api::V1::TelegramWebhookController < ApplicationController
  skip_before_action :authenticate_request
  before_action :verify_telegram_request
  
  private
  
  def verify_telegram_request
    secret_token = ENV['TELEGRAM_WEBHOOK_SECRET']
    received_token = request.headers['X-Telegram-Bot-Api-Secret-Token']
    
    unless secret_token.present? && received_token.present?
      Rails.logger.warn "🚫 Telegram webhook: отсутствует Secret Token"
      head :unauthorized
      return
    end
    
    unless ActiveSupport::SecurityUtils.secure_compare(secret_token, received_token)
      Rails.logger.warn "🚫 Telegram webhook: неверный Secret Token"
      head :unauthorized
      return
    end
    
    Rails.logger.info "✅ Telegram webhook: авторизация успешна"
  end
end
```

4. **Установите webhook с Secret Token:**

```bash
curl -X POST "https://api.telegram.org/bot<NEW_TOKEN>/setWebhook" \
  -d "url=https://yourdomain.com/api/v1/telegram_webhook" \
  -d "secret_token=<YOUR_SECRET_TOKEN>"
```

## 🧪 ТЕСТИРОВАНИЕ БЕЗОПАСНОСТИ

### 1. Проверка webhook:
```bash
# Должен вернуть 401 Unauthorized
curl -X POST https://yourdomain.com/api/v1/telegram_webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "unauthorized"}'

# Должен вернуть 200 OK (с правильным Secret Token)
curl -X POST https://yourdomain.com/api/v1/telegram_webhook \
  -H "Content-Type: application/json" \
  -H "X-Telegram-Bot-Api-Secret-Token: ваш_секретный_ключ" \
  -d '{"test": "authorized"}'
```

### 2. Тест бота:
1. Найдите нового бота в Telegram
2. Отправьте `/start`
3. Проверьте, что бот отвечает корректно
4. Убедитесь, что нет спам-сообщений

## 📊 МОНИТОРИНГ БЕЗОПАСНОСТИ

### Добавьте в логи мониторинг:
```bash
# Мониторинг подозрительной активности
tail -f log/production.log | grep -E "(telegram|webhook|unauthorized|suspicious)"
```

### Настройте алерты:
```ruby
# В контроллере webhook
if unauthorized_attempt
  Rails.logger.error "🚨 БЕЗОПАСНОСТЬ: Несанкционированная попытка доступа к Telegram webhook"
  # Отправить уведомление администратору
end
```

## ⚠️ ВАЖНЫЕ ПРАВИЛА БЕЗОПАСНОСТИ

### ✅ ДЕЛАЙТЕ:
- Используйте только HTTPS для webhook
- Всегда проверяйте Secret Token
- Храните токен в переменных окружения
- Регулярно проверяйте логи на подозрительную активность
- Используйте собственный домен с SSL

### ❌ НЕ ДЕЛАЙТЕ:
- НЕ используйте ngrok для production
- НЕ публикуйте токен в коде или логах
- НЕ настраивайте webhook без Secret Token
- НЕ игнорируйте подозрительную активность
- НЕ используйте HTTP (только HTTPS)

## 🎯 ЧЕКЛИСТ БЕЗОПАСНОСТИ

- [ ] ✅ Старый токен отозван через @BotFather
- [ ] ✅ Создан новый бот с новым токеном  
- [ ] 🔒 Токен сохранен в переменных окружения
- [ ] 🔑 Сгенерирован Secret Token для webhook
- [ ] 🌐 Настроен SSL домен (не ngrok)
- [ ] 🛡️ Добавлена проверка Secret Token в код
- [ ] 📊 Настроен мониторинг безопасности
- [ ] 🧪 Проведено тестирование безопасности

## 🆘 ЕСЛИ ЧТО-ТО ПОШЛО НЕ ТАК

### Экстренные действия:
1. Немедленно отзовите токен через @BotFather
2. Отключите webhook: `/deleteWebhook`
3. Проверьте логи на подозрительную активность
4. Создайте нового бота с нуля

### Контакты поддержки:
- Telegram: @BotFather (официальная поддержка)
- Документация: https://core.telegram.org/bots/webhooks

---

**🔒 ПОМНИТЕ: Безопасность бота = безопасность ваших пользователей!**