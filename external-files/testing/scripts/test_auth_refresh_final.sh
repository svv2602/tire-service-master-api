#!/bin/bash

# Тест исправления проблемы с обновлением страницы
# Проверяем, что пользователь не перекидывается на /login при обновлении

echo "🔧 Тестирование исправления проблемы с обновлением страницы"
echo "============================================================"

# Функция для красивого вывода
print_step() {
    echo ""
    echo "📋 $1"
    echo "----------------------------------------"
}

print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

print_warning() {
    echo "⚠️ $1"
}

# Проверяем, что API запущен
print_step "Проверяем доступность API"
if curl -s http://localhost:8000/api/v1/health > /dev/null 2>&1; then
    print_success "API доступен на http://localhost:8000"
else
    print_error "API недоступен! Запустите API сервер."
    exit 1
fi

# Проверяем, что фронтенд запущен
print_step "Проверяем доступность фронтенда"
if curl -s http://localhost:3008 > /dev/null 2>&1; then
    print_success "Фронтенд доступен на http://localhost:3008"
else
    print_error "Фронтенд недоступен! Запустите React приложение."
    exit 1
fi

# Тестируем логин через API
print_step "Тестируем логин через API"
LOGIN_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@test.com","password":"admin123"}' \
    http://localhost:8000/api/v1/auth/login)

if echo "$LOGIN_RESPONSE" | jq -e '.tokens.access' > /dev/null 2>&1; then
    ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.tokens.access')
    USER_DATA=$(echo "$LOGIN_RESPONSE" | jq '.user')
    print_success "Логин успешен, получен токен"
    echo "   Токен: ${ACCESS_TOKEN:0:50}..."
    echo "   Пользователь: $(echo "$USER_DATA" | jq -r '.first_name + " " + .last_name')"
else
    print_error "Ошибка логина через API"
    echo "$LOGIN_RESPONSE"
    exit 1
fi

# Тестируем /auth/me с токеном
print_step "Тестируем /auth/me с токеном"
AUTH_ME_RESPONSE=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8000/api/v1/auth/me)

if echo "$AUTH_ME_RESPONSE" | jq -e '.user' > /dev/null 2>&1; then
    print_success "/auth/me работает с токеном"
    echo "   Пользователь: $(echo "$AUTH_ME_RESPONSE" | jq -r '.user.first_name + " " + .user.last_name')"
    echo "   Роль: $(echo "$AUTH_ME_RESPONSE" | jq -r '.user.role')"
else
    print_error "/auth/me не работает с токеном"
    echo "$AUTH_ME_RESPONSE"
    exit 1
fi

print_step "Результаты тестирования"
print_success "Все API тесты прошли успешно!"
print_warning "Теперь нужно протестировать фронтенд:"

echo ""
echo "📝 Инструкция для ручного тестирования:"
echo "1. Откройте http://localhost:3008 в браузере"
echo "2. Войдите в систему с учетными данными:"
echo "   Email: admin@test.com"
echo "   Password: admin123"
echo "3. Перейдите на любую защищенную страницу (Dashboard, Users, и т.д.)"
echo "4. Обновите страницу (F5 или Ctrl+R)"
echo "5. Убедитесь, что вас НЕ перекидывает на /login"
echo ""

print_step "Проверка localStorage"
echo "После входа в систему, проверьте в DevTools (F12 -> Application -> Local Storage):"
echo "• tvoya_shina_user - должен содержать данные пользователя"
echo "• tvoya_shina_access_token - должен содержать access token"
echo ""

print_step "Автоматическое открытие тестовой страницы"
echo "Открываем тестовую страницу для проверки..."

# Открываем тестовую страницу в браузере (если доступен)
if command -v xdg-open > /dev/null 2>&1; then
    xdg-open "file://$(pwd)/test_auth_refresh_fix.html" 2>/dev/null &
    print_success "Открыта тестовая страница"
elif command -v open > /dev/null 2>&1; then
    open "file://$(pwd)/test_auth_refresh_fix.html" 2>/dev/null &
    print_success "Открыта тестовая страница"
else
    print_warning "Откройте вручную: file://$(pwd)/test_auth_refresh_fix.html"
fi

echo ""
print_success "Тест завершен! Проверьте фронтенд вручную согласно инструкции выше."
