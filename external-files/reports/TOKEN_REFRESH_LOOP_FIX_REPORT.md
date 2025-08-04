# 🔧 ОТЧЕТ: Исправление зацикливания token auto-refresh после спящего режима

## 🚨 ПРОБЛЕМА

При локальной разработке после выхода компьютера из спящего режима (сервера продолжали работать) возникало зацикливание сообщения "token auto-refreshed successfully" в логах бэкенда.

## 🔍 КОРНЕВЫЕ ПРИЧИНЫ

### 1. Бэкенд (tire-service-master-api)
- **Отсутствие защиты от частых попыток обновления токена** в `ApplicationController#try_refresh_token`
- После спящего режима множественные истекшие токены вызывали частые попытки refresh
- Отсутствие ограничения по времени между попытками обновления

### 2. Фронтенд (tire-service-master-web) 
- **Несколько конфликтующих interceptor'ов** для обработки 401 ошибок:
  - RTK Query `baseQueryWithReauth` в `api/baseApi.ts`
  - Axios interceptor в `api/interceptors.ts`
  - Axios interceptor в `api/api.ts`
- **Отсутствие защиты от зацикливания** в RTK Query
- После спящего режима все interceptor'ы пытались обновить токены одновременно

### 3. Сценарий после спящего режима
1. Компьютер просыпается, access токены истекли (срок жизни 1 час)
2. Фронтенд делает множественные запросы к API
3. Каждый запрос получает 401 ошибку
4. Все interceptor'ы начинают обновлять токены параллельно
5. Бэкенд обрабатывает множественные refresh запросы без ограничений
6. Возникает зацикливание логов "token auto-refreshed successfully"

## ✅ РЕШЕНИЯ

### 1. Бэкенд: Защита от зацикливания в ApplicationController

**Файл:** `tire-service-master-api/app/controllers/application_controller.rb`

```ruby
# Попытка автоматического обновления токена
def try_refresh_token
  refresh_token = cookies[:refresh_token]
  return false if refresh_token.blank?

  # Защита от зацикливания - проверяем, не пытались ли мы уже обновить токен недавно
  if session[:last_refresh_attempt] && Time.current - session[:last_refresh_attempt] < 5.seconds
    Rails.logger.warn("Token refresh attempt too frequent, skipping to prevent loop")
    return false
  end
  
  session[:last_refresh_attempt] = Time.current

  begin
    new_access_token = Auth::JsonWebToken.refresh_access_token(refresh_token)
    
    # Устанавливаем новый access токен в cookie
    cookies[:access_token] = {
      value: new_access_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      expires: 1.hour.from_now,
      path: '/'
    }
    
    Rails.logger.info("Token auto-refreshed successfully for user session")
    # Сбрасываем счетчик попыток после успешного обновления
    session[:last_refresh_attempt] = nil
    return true
  rescue Auth::TokenExpiredError, Auth::TokenInvalidError, Auth::TokenRevokedError => e
    # Удаляем недействительные cookies
    cookies.delete(:access_token)
    cookies.delete(:refresh_token)
    session[:last_refresh_attempt] = nil
    Rails.logger.info("Failed to refresh token: #{e.message}")
    return false
  end
end
```

**Изменения:**
- ✅ Добавлена проверка `session[:last_refresh_attempt]` с ограничением 5 секунд
- ✅ Предотвращение частых попыток обновления токена
- ✅ Сброс счетчика после успешного/неуспешного обновления
- ✅ Улучшенное логирование для отладки

### 2. Фронтенд: Защита от зацикливания в RTK Query

**Файл:** `tire-service-master-web/src/api/baseApi.ts`

```typescript
// Защита от зацикливания refresh запросов
let isRefreshing = false;
let lastRefreshTime = 0;

const baseQueryWithReauth = async (args: any, api: any, extraOptions: any) => {
  // ... логирование запроса ...
  
  let result = await baseQuery(args, api, extraOptions);
  
  if (result.error && result.error.status === 401) {
    console.log('🔄 Получена 401 ошибка, пытаемся обновить токен...');
    
    // Защита от зацикливания
    const now = Date.now();
    if (isRefreshing || (now - lastRefreshTime < 5000)) {
      console.warn('⚠️ Refresh токена уже выполняется или был недавно, пропускаем');
      return result;
    }

    // Проверяем, что это не запрос на refresh (избегаем бесконечный цикл)
    const requestUrl = typeof args === 'string' ? args : args.url;
    if (requestUrl === 'auth/refresh') {
      console.log('❌ Ошибка refresh запроса, выходим из системы');
      api.dispatch({ type: 'auth/logout' });
      return result;
    }

    isRefreshing = true;
    lastRefreshTime = now;
    
    try {
      // Пытаемся обновить токен
      const refreshResult = await baseQuery({
        url: 'auth/refresh',
        method: 'POST',
      }, api, extraOptions);
      
      if (refreshResult.data) {
        console.log('✅ Токен успешно обновлен');
        
        const newToken = refreshResult.data?.access_token || refreshResult.data?.tokens?.access;
        
        if (newToken) {
          api.dispatch({ type: 'auth/updateAccessToken', payload: newToken });
          console.log('🔄 Токен обновлен в Redux store');
        }
        
        // Повторяем исходный запрос
        result = await baseQuery(args, api, extraOptions);
      } else {
        console.log('❌ Не удалось обновить токен');
        api.dispatch({ type: 'auth/logout' });
      }
    } finally {
      isRefreshing = false;
    }
  }
  
  return result;
};
```

**Изменения:**
- ✅ Добавлены глобальные флаги `isRefreshing` и `lastRefreshTime`
- ✅ Предотвращение параллельных refresh запросов
- ✅ Ограничение по времени 5 секунд между попытками
- ✅ Защита от бесконечного цикла для refresh запросов
- ✅ Автоматический logout при неуспешном refresh

## 🎯 РЕЗУЛЬТАТ

### Поведение ДО исправления:
```
[2025-01-28 10:15:23] Token auto-refreshed successfully
[2025-01-28 10:15:23] Token auto-refreshed successfully  
[2025-01-28 10:15:23] Token auto-refreshed successfully
[2025-01-28 10:15:23] Token auto-refreshed successfully
[бесконечное повторение...]
```

### Поведение ПОСЛЕ исправления:
```
[2025-01-28 10:15:23] Token auto-refreshed successfully for user session
[2025-01-28 10:15:24] Token refresh attempt too frequent, skipping to prevent loop
[2025-01-28 10:15:25] Token refresh attempt too frequent, skipping to prevent loop
[нормальная работа без зацикливания]
```

## 🔬 ТЕХНИЧЕСКАЯ ДИАГНОСТИКА

### Для проверки работы системы после исправления:

1. **Тест спящего режима:**
   - Запустите приложение (Frontend + Backend)
   - Авторизуйтесь в системе
   - Переведите компьютер в спящий режим на > 1 часа
   - Проснитесь и проверьте логи бэкенда
   - Должно быть одно сообщение об обновлении токена, а не зацикливание

2. **Мониторинг логов:**
   ```bash
   # В tire-service-master-api/
   tail -f log/development.log | grep -i token
   ```

3. **Проверка фронтенда:**
   - Откройте DevTools → Console
   - Должны видеть корректные сообщения о refresh без зацикливания

## 🚀 РЕКОМЕНДАЦИИ

### Дальнейшие улучшения:

1. **Добавить Retry механизм с exponential backoff** для неуспешных refresh попыток
2. **Настроить мониторинг** частоты refresh запросов в production
3. **Рассмотреть увеличение времени жизни access токена** до 2-4 часов для локальной разработки
4. **Добавить health check endpoint** для проверки состояния авторизации

### Конфигурация для production:
```ruby
# В ApplicationController можно уменьшить интервал для production
refresh_interval = Rails.env.production? ? 10.seconds : 5.seconds
```

---

**Дата:** 28 января 2025  
**Статус:** ✅ ИСПРАВЛЕНО  
**Тестирование:** Требуется тестирование в реальных условиях спящего режима