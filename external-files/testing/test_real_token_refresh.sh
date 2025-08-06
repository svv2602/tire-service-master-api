#!/bin/bash

# Реалистичный тест с авторизацией и симуляцией спящего режима
echo "🧪 Реалистичный тест token refresh с авторизацией"
echo "================================================="

# Очищаем логи для чистого теста
echo "" > log/development.log
echo "🧹 Логи очищены"

# Авторизуемся и получаем cookies
echo "🔐 Авторизуемся как admin@test.com..."
AUTH_RESPONSE=$(curl -s -c /tmp/cookies.txt \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"auth":{"email":"admin@test.com","password":"admin123"}}' \
  http://localhost:8000/api/v1/auth/login)

if echo "$AUTH_RESPONSE" | grep -q "access_token"; then
  echo "✅ Авторизация успешна"
else
  echo "❌ Ошибка авторизации: $AUTH_RESPONSE"
  exit 1
fi

# Проверяем cookies
echo "🍪 Cookies файл:"
cat /tmp/cookies.txt

echo ""
echo "🚀 Делаем 5 параллельных запросов с cookies (симуляция после спящего режима)..."

# Запускаем несколько параллельных запросов с cookies
for i in {1..5}; do
  curl -s -b /tmp/cookies.txt \
    -H "Content-Type: application/json" \
    http://localhost:8000/api/v1/users \
    > /dev/null &
  echo "  Запрос $i запущен"
done

# Ждем завершения
wait
echo "✅ Все запросы завершены"

# Ждем обработки
sleep 3

echo ""
echo "📋 Логи после теста:"
cat log/development.log

echo ""
echo "🔍 Анализ результатов:"
REFRESH_COUNT=$(grep -c "Token auto-refreshed successfully" log/development.log 2>/dev/null || echo "0")
WARNING_COUNT=$(grep -c "Token refresh attempt too frequent" log/development.log 2>/dev/null || echo "0")

echo "  - Успешных refresh: $REFRESH_COUNT"
echo "  - Предупреждений о частых попытках: $WARNING_COUNT"

if [ "$REFRESH_COUNT" -le 1 ] && [ "$WARNING_COUNT" -ge 0 ]; then
  echo "✅ ТЕСТ ПРОЙДЕН: Зацикливание предотвращено!"
else
  echo "❌ ТЕСТ НЕ ПРОЙДЕН: Возможно зацикливание"
fi

# Очистка
rm -f /tmp/cookies.txt