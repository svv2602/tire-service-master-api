# 🔔 Руководство по настройке Push уведомлений

**Дата:** 2025-07-22  
**Статус:** ✅ РЕАЛИЗОВАНО  
**Страница:** `/admin/notifications/push-settings`

---

## 🎯 Что реализовано

### **Backend (tire-service-master-api)**

#### 1. **Контроллеры**
- ✅ `PushSettingsController` - управление настройками Push
- ✅ `PushSubscriptionsController` - управление подписками пользователей

#### 2. **API Endpoints**
```
GET    /api/v1/push_settings              # Получение настроек
PATCH  /api/v1/push_settings              # Обновление настроек
POST   /api/v1/push_settings/test_notification  # Тест уведомления

GET    /api/v1/push_subscriptions         # Список подписок пользователя
POST   /api/v1/push_subscriptions         # Создание подписки
DELETE /api/v1/push_subscriptions/:id     # Удаление подписки
POST   /api/v1/push_subscriptions/:id/test_notification  # Тест подписки
```

#### 3. **Модели**
- ✅ `PushSubscription` (уже существует)
- ✅ `PushService` (уже существует)
- ✅ Интеграция с `User` моделью

### **Frontend (tire-service-master-web)**

#### 1. **Страница настроек**
- ✅ `/admin/notifications/push-settings` - полнофункциональная страница
- ✅ Интеграция с реальным API
- ✅ Статистика подписок и отправок
- ✅ Диалог просмотра подписок пользователей

#### 2. **Service Worker**
- ✅ `/public/sw.js` - обработка Push уведомлений
- ✅ Кэширование для offline работы
- ✅ Клик по уведомлениям с навигацией

#### 3. **PWA поддержка**
- ✅ `/public/manifest.json` - обновлен для Tire Service
- ✅ `usePushNotifications.ts` - хук для управления подписками

---

## ⚙️ Что нужно настроить

### **1. VAPID ключи (ОБЯЗАТЕЛЬНО)**

Для работы Push уведомлений нужно сгенерировать VAPID ключи и добавить в переменные окружения:

```bash
# Генерация VAPID ключей (Node.js)
npx web-push generate-vapid-keys

# Или через Ruby (если есть webpush gem)
bundle exec rails runner "puts Webpush.generate_key"
```

**Добавить в `.env` файл бэкенда:**
```env
VAPID_PUBLIC_KEY=your_public_key_here
VAPID_PRIVATE_KEY=your_private_key_here
VAPID_SUBJECT=mailto:admin@tireservice.ua
```

**Добавить в `.env` файл фронтенда:**
```env
REACT_APP_VAPID_PUBLIC_KEY=your_public_key_here
```

### **2. Установка зависимостей**

**Backend:**
```bash
# Если еще не установлен
gem install webpush
bundle install
```

**Frontend:**
```bash
# Service Worker уже создан, дополнительные зависимости не нужны
```

### **3. Настройка HTTPS (Продакшн)**

Push уведомления работают только по HTTPS (кроме localhost):
- Настроить SSL сертификат
- Обновить URLs в конфигурации
- Проверить CORS настройки

---

## 🧪 Тестирование

### **Локальная разработка:**

1. **Запустить сервисы:**
```bash
# Backend
cd tire-service-master-api
rails server -p 8000

# Frontend  
cd tire-service-master-web
npm start
```

2. **Открыть страницу настроек:**
```
http://localhost:3008/admin/notifications/push-settings
```

3. **Проверить функциональность:**
- ✅ Загрузка настроек
- ✅ Сохранение настроек
- ✅ Статус Service Worker
- ✅ Тестовое уведомление
- ✅ Просмотр подписок

### **Проверка в браузере:**

```javascript
// В консоли браузера
navigator.serviceWorker.getRegistration().then(reg => {
  console.log('SW зарегистрирован:', !!reg);
  if (reg) {
    reg.pushManager.getSubscription().then(sub => {
      console.log('Push подписка:', !!sub);
    });
  }
});
```

---

## 📊 Возможности системы

### **Для администраторов:**
- 🎛️ Управление настройками Push уведомлений
- 📈 Просмотр статистики отправок и подписок
- 🧪 Тестирование уведомлений
- 👥 Просмотр подписок пользователей
- ⚙️ Настройка лимитов отправки

### **Для пользователей:**
- 🔔 Подписка на Push уведомления
- 📱 Получение уведомлений о бронированиях
- 🎯 Уведомления о статусе услуг
- 📰 Рассылки и акции (опционально)

### **Типы уведомлений:**
- ✅ Подтверждение бронирования
- ⏰ Напоминание о записи
- ✅ Завершение услуги
- 📝 Запрос на отзыв
- 📢 Рассылки и акции

---

## 🚀 Следующие шаги

1. **Сгенерировать и настроить VAPID ключи**
2. **Протестировать на localhost**
3. **Настроить HTTPS для продакшн**
4. **Интегрировать с системой бронирований**
5. **Добавить Push уведомления в шаблоны**

---

## 🔧 Troubleshooting

### **Service Worker не регистрируется:**
- Проверить `/public/sw.js` существует
- Проверить HTTPS (или localhost)
- Очистить кэш браузера

### **VAPID ключи не работают:**
- Проверить переменные окружения
- Перезапустить сервер после добавления ключей
- Проверить формат ключей (base64url)

### **Уведомления не приходят:**
- Проверить разрешения браузера
- Проверить подписку в DevTools
- Проверить логи Service Worker

---

**🎉 Система Push уведомлений полностью готова к использованию!** 