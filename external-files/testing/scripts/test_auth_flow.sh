#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n${BLUE}=== ТЕСТИРОВАНИЕ ПОЛНОГО ЦИКЛА АУТЕНТИФИКАЦИИ ===${NC}\n"

# Функция для проверки статуса приложений
check_services() {
    echo -e "${BLUE}[ПРОВЕРКА]${NC} Проверка статуса приложений..."
    
    # Проверяем API
    if lsof -i :8000 > /dev/null 2>&1; then
        local api_pid=$(lsof -t -i :8000)
        echo -e "${GREEN}[УСПЕШНО]${NC} API запущен (PID: $api_pid)"
    else
        echo -e "${RED}[ОШИБКА]${NC} API не запущен. Запустите его командой: ./start.sh api"
        exit 1
    fi
    
    # Проверяем фронтенд
    if lsof -i :3008 > /dev/null 2>&1; then
        local frontend_pid=$(lsof -t -i :3008)
        echo -e "${GREEN}[УСПЕШНО]${NC} Фронтенд запущен (PID: $frontend_pid)"
    else
        echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ]${NC} Фронтенд не запущен. Для полного тестирования запустите: ./start.sh frontend"
    fi
}

# Проверка доступности API
echo -e "${BLUE}[ТЕСТ]${NC} Проверка доступности API..."
API_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/v1/health)
if [[ "$API_HEALTH" == "200" ]]; then
  echo -e "${GREEN}[УСПЕШНО]${NC} API доступен (код: $API_HEALTH)"
else
  echo -e "${RED}[ОШИБКА]${NC} API не доступен (код: $API_HEALTH)"
  check_services
  exit 1
fi

# Проверка CORS с предварительным запросом OPTIONS
echo -e "\n${BLUE}[ТЕСТ]${NC} Проверка CORS настроек..."
CORS_RESPONSE=$(curl -s -I -X OPTIONS http://localhost:8000/api/v1/auth/login \
  -H "Origin: http://localhost:3008" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  -w "%{http_code}" \
  -o /dev/null)

if [[ "$CORS_RESPONSE" == "200" || "$CORS_RESPONSE" == "204" ]]; then
  echo -e "${GREEN}[УСПЕШНО]${NC} CORS настроен правильно (код: $CORS_RESPONSE)"
else
  echo -e "${RED}[ОШИБКА]${NC} Проблема с CORS настройками (код: $CORS_RESPONSE)"
fi

# Проверка аутентификации
echo -e "\n${BLUE}[ТЕСТ]${NC} Проверка аутентификации..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost:3008" \
  -d '{"email":"admin@test.com", "password":"admin"}')

if [[ "$LOGIN_RESPONSE" == *"auth_token"* ]]; then
  echo -e "${GREEN}[УСПЕШНО]${NC} Аутентификация работает"
  # Извлекаем токен
  AUTH_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"auth_token":"[^"]*' | cut -d'"' -f4)
  echo -e "${GREEN}[ТОКЕН]${NC} Получен валидный токен"
else
  echo -e "${RED}[ОШИБКА]${NC} Аутентификация не работает"
  echo "Ответ API: $LOGIN_RESPONSE"
  exit 1
fi

# Проверка получения данных пользователя с токеном
echo -e "\n${BLUE}[ТЕСТ]${NC} Проверка получения данных пользователя..."
USER_RESPONSE=$(curl -s -X GET http://localhost:8000/api/v1/users/me \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Origin: http://localhost:3008")

if [[ "$USER_RESPONSE" == *"id"* ]]; then
  echo -e "${GREEN}[УСПЕШНО]${NC} Получение данных пользователя работает"
  echo -e "Данные пользователя получены успешно"
else
  echo -e "${RED}[ОШИБКА]${NC} Не удалось получить данные пользователя"
  echo "Ответ API: $USER_RESPONSE"
fi

# Проверка доступности фронтенда
echo -e "\n${BLUE}[ТЕСТ]${NC} Проверка доступности фронтенда..."
FRONTEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3008)
if [[ "$FRONTEND_RESPONSE" == "200" ]]; then
  echo -e "${GREEN}[УСПЕШНО]${NC} Фронтенд доступен (код: $FRONTEND_RESPONSE)"
else
  echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ]${NC} Фронтенд не доступен (код: $FRONTEND_RESPONSE)"
  echo -e "Запустите фронтенд командой: ./start.sh frontend"
fi

# Вывод инструкций для проверки в браузере
echo -e "\n${YELLOW}[ИНСТРУКЦИИ ДЛЯ ПРОВЕРКИ В БРАУЗЕРЕ]${NC}"
echo -e "1. Откройте браузер и перейдите по адресу: http://localhost:3008/login"
echo -e "2. Используйте следующие учетные данные:"
echo -e "   - Email: admin@test.com"
echo -e "   - Пароль: admin"
echo -e "3. После успешного входа вы должны быть перенаправлены на /dashboard"
echo -e "4. Откройте инструменты разработчика (F12) для просмотра сетевых запросов"

# Отладочная информация
echo -e "\n${BLUE}[ОТЛАДКА]${NC} Для ручной отладки в консоли браузера:"
echo -e "${YELLOW}localStorage.setItem('tvoya_shina_token', '$AUTH_TOKEN'); window.location.href = '/dashboard';${NC}"

echo -e "\n${BLUE}=== ТЕСТИРОВАНИЕ ЗАВЕРШЕНО ===${NC}\n"
