#!/bin/bash

echo "🧪 Тест аутентификации при обновлении страницы"
echo "================================================"

# Проверяем, что API сервер запущен
echo "1. Проверяем API сервер..."
if curl -s http://localhost:8000/api/v1/health > /dev/null 2>&1; then
    echo "✅ API сервер запущен"
else
    echo "❌ API сервер не отвечает"
    exit 1
fi

# Проверяем, что фронтенд запущен
echo "2. Проверяем фронтенд сервер..."
if curl -s http://localhost:3008 > /dev/null 2>&1; then
    echo "✅ Фронтенд сервер запущен"
else
    echo "❌ Фронтенд сервер не отвечает"
    exit 1
fi

# Тестируем логин через API
echo "3. Тестируем логин через API..."
LOGIN_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"admin123"}' \
  -c cookies.txt \
  http://localhost:8000/api/v1/auth/login)

if echo "$LOGIN_RESPONSE" | grep -q '"access"'; then
    echo "✅ Логин через API успешен"
    echo "📄 Ответ логина: $LOGIN_RESPONSE"
else
    echo "❌ Ошибка логина через API"
    echo "📄 Ответ: $LOGIN_RESPONSE"
    exit 1
fi

# Проверяем /auth/me с cookies
echo "4. Тестируем /auth/me с cookies..."
ME_RESPONSE=$(curl -s -b cookies.txt http://localhost:8000/api/v1/auth/me)

if echo "$ME_RESPONSE" | grep -q '"user"'; then
    echo "✅ /auth/me работает с cookies"
    echo "📄 Ответ /auth/me: $ME_RESPONSE"
else
    echo "❌ /auth/me не работает с cookies"
    echo "📄 Ответ: $ME_RESPONSE"
fi

# Проверяем содержимое cookies
echo "5. Проверяем cookies..."
if [ -f cookies.txt ]; then
    echo "📄 Содержимое cookies.txt:"
    cat cookies.txt
    
    if grep -q "refresh" cookies.txt; then
        echo "✅ Refresh token найден в cookies"
    else
        echo "❌ Refresh token не найден в cookies"
    fi
else
    echo "❌ Файл cookies.txt не создан"
fi

# Очищаем временные файлы
rm -f cookies.txt

echo ""
echo "🎯 Рекомендации для тестирования:"
echo "1. Откройте http://localhost:3008/login"
echo "2. Войдите как admin@test.com / admin123"
echo "3. Перейдите на дашборд"
echo "4. Обновите страницу (F5 или Ctrl+R)"
echo "5. Проверьте, остались ли на дашборде"
