#!/bin/bash

# Тест исправления зацикливания token refresh после спящего режима
# Симулируем множественные параллельные запросы с недействительными токенами

echo "🧪 Тест исправления зацикливания token refresh"
echo "================================================"

# Создаем недействительный токен для симуляции истекшего
INVALID_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

# Логи до теста
echo "📋 Логи до теста (последние 5 строк):"
tail -n 5 log/development.log

echo ""
echo "🚀 Запускаем 10 параллельных запросов с недействительными токенами..."

# Запускаем 10 параллельных запросов
for i in {1..10}; do
  curl -s \
    -H "Authorization: Bearer $INVALID_TOKEN" \
    -H "Content-Type: application/json" \
    http://localhost:8000/api/v1/users \
    > /dev/null &
done

# Ждем завершения всех запросов
wait

echo "✅ Все запросы завершены"
echo ""

# Ждем немного для обработки
sleep 2

# Проверяем логи
echo "📋 Логи после теста (последние 15 строк):"
tail -n 15 log/development.log

echo ""
echo "🔍 Подсчет сообщений 'Token auto-refreshed successfully':"
grep -c "Token auto-refreshed successfully" log/development.log | tail -1

echo ""
echo "🔍 Подсчет предупреждений о частых попытках:"
grep -c "Token refresh attempt too frequent" log/development.log | tail -1

echo ""
echo "✅ Тест завершен!"