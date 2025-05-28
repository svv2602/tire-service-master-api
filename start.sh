#!/bin/bash
# Скрипт для запуска приложений из проекта mobi_tz
# Автор: GitHub Copilot
# Дата: 22 мая 2025 г.
# Обновлено: 27 мая 2025 г.

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Пути к директориям
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$SCRIPT_DIR/tire-service-master-api"
FRONTEND_DIR="$SCRIPT_DIR/tire-service-master-web"

# Порты
API_PORT=8000
FRONTEND_PORT=3008

# Переменная для контроля пересоздания базы данных
RESET_DB=false

# Функция для логирования
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} [$timestamp] $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} [$timestamp] $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} [$timestamp] $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} [$timestamp] $message"
            ;;
        "DEBUG")
            echo -e "${CYAN}[DEBUG]${NC} [$timestamp] $message"
            ;;
    esac
}

# Функция для проверки существования директорий
check_directories() {
    log "INFO" "Проверяем структуру проекта..."
    
    if [ ! -d "$API_DIR" ]; then
        log "ERROR" "Директория API не найдена: $API_DIR"
        return 1
    fi
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        log "ERROR" "Директория фронтенда не найдена: $FRONTEND_DIR"
        return 1
    fi
    
    if [ ! -f "$API_DIR/Gemfile" ]; then
        log "ERROR" "Не найден Gemfile в директории API: $API_DIR/Gemfile"
        return 1
    fi
    
    if [ ! -f "$FRONTEND_DIR/package.json" ]; then
        log "ERROR" "Не найден package.json в директории фронтенда: $FRONTEND_DIR/package.json"
        return 1
    fi
    
    log "SUCCESS" "Структура проекта корректна"
    return 0
}

# Функция для проверки, занят ли порт
check_port() {
    local port=$1
    local name=$2
    
    if lsof -i :$port > /dev/null 2>&1; then
        log "WARNING" "Порт $port ($name) уже используется другим процессом."
        echo -e "Хотите освободить этот порт? (y/n)"
        read -r answer
        
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            log "INFO" "Завершаем процесс, использующий порт $port..."
            
            # Находим PID процесса, использующего порт и завершаем его
            pid=$(lsof -t -i :$port)
            if [ -n "$pid" ]; then
                kill -9 $pid
                sleep 2
                if ! lsof -i :$port > /dev/null 2>&1; then
                    log "SUCCESS" "Порт $port освобожден."
                else
                    log "ERROR" "Не удалось освободить порт $port."
                    return 1
                fi
            else
                log "ERROR" "Не удалось найти процесс, использующий порт $port."
                return 1
            fi
        else
            log "INFO" "Действие отменено. Порт $port остается занятым."
            return 1
        fi
    else
        log "SUCCESS" "Порт $port ($name) свободен."
    fi
    return 0
}

# Функция для проверки состояния PostgreSQL
check_postgres() {
    log "INFO" "Проверяем состояние PostgreSQL..."
    
    # Проверяем, установлен ли PostgreSQL
    if ! command -v psql &> /dev/null && ! command -v pg_isready &> /dev/null; then
        log "ERROR" "PostgreSQL не установлен. Установите PostgreSQL для работы с API."
        return 1
    fi
    
    # Проверяем, запущен ли PostgreSQL
    if command -v pg_isready &> /dev/null; then
        if ! pg_isready -q; then
            log "WARNING" "PostgreSQL не запущен или недоступен."
        echo -e "Хотите попробовать запустить PostgreSQL? (y/n)"
        read -r answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
                log "INFO" "Пытаемся запустить PostgreSQL..."
                if sudo service postgresql start; then
                    sleep 3
                    if pg_isready -q; then
                        log "SUCCESS" "PostgreSQL успешно запущен."
                    else
                        log "ERROR" "PostgreSQL запущен, но недоступен."
                        return 1
                    fi
                else
                    log "ERROR" "Не удалось запустить PostgreSQL."
                    return 1
                fi
            else
                log "WARNING" "PostgreSQL не запущен. API может не работать корректно."
                return 1
            fi
        else
            log "SUCCESS" "PostgreSQL работает."
        fi
    else
        log "WARNING" "Утилита pg_isready не найдена. Пропускаем проверку PostgreSQL."
    fi
    
    return 0
}

# Функция для проверки здоровья API
check_api_health() {
    local max_attempts=30
    local attempt=1
    
    log "INFO" "Проверяем доступность API..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "http://localhost:$API_PORT/health" > /dev/null 2>&1; then
            log "SUCCESS" "API доступен и отвечает на запросы."
            return 0
        elif curl -s -f "http://localhost:$API_PORT/" > /dev/null 2>&1; then
            log "SUCCESS" "API доступен (проверка через корневой путь)."
            return 0
        fi
        
        if [ $attempt -eq 1 ]; then
            log "INFO" "Ожидаем запуска API..."
        fi
        
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log "ERROR" "API не отвечает после $max_attempts попыток."
    return 1
}

# Функция для проверки здоровья фронтенда
check_frontend_health() {
    local max_attempts=60
    local attempt=1
    
    log "INFO" "Проверяем доступность фронтенда..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "http://localhost:$FRONTEND_PORT/" > /dev/null 2>&1; then
            log "SUCCESS" "Фронтенд доступен и отвечает на запросы."
            return 0
        fi
        
        if [ $attempt -eq 1 ]; then
            log "INFO" "Ожидаем запуска фронтенда..."
        fi
        
        sleep 3
        attempt=$((attempt + 1))
    done
    
    log "ERROR" "Фронтенд не отвечает после $max_attempts попыток."
    return 1
}

# Функция для запуска API (бэкенд)
start_api() {
    local background=$1
    local log_file="$SCRIPT_DIR/logs/api_$(date +"%Y%m%d_%H%M%S").log"
    
    log "INFO" "Запускаем API на порту $API_PORT..."
    
    # Проверяем структуру проекта
    if ! check_directories; then
        return 1
    fi
    
    cd "$API_DIR" || { 
        log "ERROR" "Не удалось перейти в директорию API: $API_DIR"
        return 1
    }
    
    # Проверяем состояние PostgreSQL
    if ! check_postgres; then
        log "WARNING" "Продолжаем без проверки PostgreSQL..."
    fi
    
    # Проверяем наличие bundler и устанавливаем при необходимости
    if ! command -v bundle &> /dev/null; then
        log "WARNING" "Bundler не найден. Устанавливаем bundler..."
        if ! gem install bundler; then
            log "ERROR" "Не удалось установить bundler. Проверьте установку Ruby."
            return 1
        fi
        log "SUCCESS" "Bundler успешно установлен."
    fi
    
    # Проверяем, установлены ли зависимости
    if [ ! -d "$API_DIR/vendor/bundle" ] && [ ! -f "$API_DIR/Gemfile.lock" ]; then
        log "INFO" "Устанавливаем зависимости для API..."
        if ! bundle install; then
            log "ERROR" "Не удалось установить зависимости для API."
            return 1
        fi
    fi
    
    # Проверяем настройки базы данных
    if [ ! -f "$API_DIR/config/database.yml" ]; then
        log "ERROR" "Не найден файл конфигурации базы данных."
        return 1
    fi
    
    # Опрашиваем пользователя о действиях с базой данных, если RESET_DB не установлен
    if [ "$RESET_DB" = false ]; then
        echo -e "${YELLOW}[БАЗА ДАННЫХ]${NC} Выберите действие:"
        echo "1. Только запустить приложение (без изменения базы)"
        echo "2. Запустить миграции"
        echo "3. Пересоздать базу данных и загрузить seed данные"
        read -p "Выберите опцию (1-3): " db_action
        
        case $db_action in
            2)
                log "INFO" "Запуск миграций..."
                if ! RAILS_ENV=development bundle exec rails db:migrate; then
                    log "ERROR" "Не удалось выполнить миграции."
                    return 1
                fi
                log "SUCCESS" "Миграции выполнены."
                ;;
            3)
                log "INFO" "Пересоздание базы данных..."
                if ! RAILS_ENV=development bundle exec rails db:drop db:create db:migrate db:seed; then
                    log "ERROR" "Не удалось пересоздать базу данных."
                    return 1
                fi
                log "SUCCESS" "База данных пересоздана и заполнена."
                ;;
            *)
                log "INFO" "Пропускаем операции с базой данных."
                ;;
        esac
    else
        # Если RESET_DB=true, пересоздаем базу
        log "INFO" "Пересоздание базы данных..."
        if ! RAILS_ENV=development bundle exec rails db:drop db:create db:migrate db:seed; then
            log "ERROR" "Не удалось пересоздать базу данных."
            return 1
        fi
        log "SUCCESS" "База данных пересоздана и заполнена."
    fi
    
    # Создаем директорию для логов
    mkdir -p "$SCRIPT_DIR/logs"
    
    # Запускаем сервер Rails
    if [ "$background" = true ]; then
        log "INFO" "Запускаем Rails сервер в фоновом режиме..."
        log "INFO" "Логи будут записаны в $log_file"
        
        # Запускаем с nohup для гарантированной работы в фоне
        nohup bundle exec rails server -p $API_PORT -b 0.0.0.0 > "$log_file" 2>&1 &
        local api_pid=$!
        
        # Сохраняем PID
        echo $api_pid > "$SCRIPT_DIR/.api.pid"
        
        # Проверяем здоровье API
        if check_api_health; then
            log "SUCCESS" "API запущен в фоновом режиме (PID: $api_pid)."
            log "INFO" "API доступен по адресу: http://localhost:$API_PORT"
        else
            log "ERROR" "API не запустился корректно. Проверьте логи: $log_file"
            kill -9 $api_pid 2>/dev/null
            rm -f "$SCRIPT_DIR/.api.pid"
            return 1
        fi
    else
        log "INFO" "API запускается в активном режиме. Для остановки нажмите Ctrl+C."
        RAILS_ENV=development bundle exec rails server -p $API_PORT -b 0.0.0.0
    fi
    
    return 0
}

# Функция для запуска фронтенда
start_frontend() {
    local background=$1
    local log_file="$SCRIPT_DIR/logs/frontend_$(date +"%Y%m%d_%H%M%S").log"
    
    log "INFO" "Запускаем фронтенд на порту $FRONTEND_PORT..."
    
    # Проверяем структуру проекта
    if ! check_directories; then
        return 1
    fi
    
    cd "$FRONTEND_DIR" || { 
        log "ERROR" "Не удалось перейти в директорию фронтенда: $FRONTEND_DIR"
        return 1
    }
    
    # Проверяем, установлены ли зависимости
    if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
        log "INFO" "Устанавливаем зависимости для фронтенда..."
        if ! npm install; then
            log "ERROR" "Не удалось установить зависимости для фронтенда."
            return 1
        fi
    fi
    
    # Экспортируем переменную с портом
    export PORT=$FRONTEND_PORT
    
    # Создаем директорию для логов
    mkdir -p "$SCRIPT_DIR/logs"
    
    # Запускаем React приложение
    if [ "$background" = true ]; then
        log "INFO" "Запускаем React приложение в фоновом режиме..."
        log "INFO" "Логи будут записаны в $log_file"
        
        # Запускаем с nohup для гарантированной работы в фоне
        nohup npm start > "$log_file" 2>&1 &
        local frontend_pid=$!
        
        # Сохраняем PID
        echo $frontend_pid > "$SCRIPT_DIR/.frontend.pid"
        
        # Проверяем здоровье фронтенда
        if check_frontend_health; then
            log "SUCCESS" "Фронтенд запущен в фоновом режиме (PID: $frontend_pid)."
            log "INFO" "Фронтенд доступен по адресу: http://localhost:$FRONTEND_PORT"
        else
            log "ERROR" "Фронтенд не запустился корректно. Проверьте логи: $log_file"
            kill -9 $frontend_pid 2>/dev/null
            rm -f "$SCRIPT_DIR/.frontend.pid"
            return 1
        fi
    else
        log "INFO" "Фронтенд запускается в активном режиме. Для остановки нажмите Ctrl+C."
        npm start
    fi
    
    return 0
}

# Функция для запуска обоих приложений в фоновом режиме
start_all_background() {
    log "INFO" "Запускаем все приложения в фоновом режиме..."
    
    # Проверяем структуру проекта
    if ! check_directories; then
        return 1
    fi
    
    check_port $API_PORT "API"
    check_port $FRONTEND_PORT "Фронтенд"
    
    # Создаем директорию для логов, если она не существует
    mkdir -p "$SCRIPT_DIR/logs"
    
    # Запускаем API и фронтенд в фоновом режиме
    if start_api true; then
        log "SUCCESS" "API успешно запущен"
    else
        log "ERROR" "Не удалось запустить API"
        return 1
    fi
    
    if start_frontend true; then
        log "SUCCESS" "Фронтенд успешно запущен"
    else
        log "ERROR" "Не удалось запустить фронтенд"
        # Останавливаем API, если фронтенд не запустился
        stop_all
        return 1
    fi
    
    log "SUCCESS" "Все приложения запущены в фоновом режиме."
    log "INFO" "Логи доступны в директории: $SCRIPT_DIR/logs/"
    log "INFO" "API доступен по адресу: http://localhost:$API_PORT"
    log "INFO" "Фронтенд доступен по адресу: http://localhost:$FRONTEND_PORT"
    
    return 0
}

# Функция для остановки всех приложений
stop_all() {
    log "INFO" "Останавливаем все запущенные приложения..."
    
    local stopped_any=false
    
    # Останавливаем API
    if [ -f "$SCRIPT_DIR/.api.pid" ]; then
        local api_pid=$(cat "$SCRIPT_DIR/.api.pid")
        if ps -p $api_pid > /dev/null 2>&1; then
            kill -TERM $api_pid 2>/dev/null
            sleep 3
            if ps -p $api_pid > /dev/null 2>&1; then
                kill -9 $api_pid 2>/dev/null
            fi
            log "SUCCESS" "API остановлен (PID: $api_pid)."
            stopped_any=true
        else
            log "WARNING" "Процесс API (PID: $api_pid) уже не существует."
        fi
        rm -f "$SCRIPT_DIR/.api.pid"
    fi
    
    # Останавливаем фронтенд
    if [ -f "$SCRIPT_DIR/.frontend.pid" ]; then
        local frontend_pid=$(cat "$SCRIPT_DIR/.frontend.pid")
        if ps -p $frontend_pid > /dev/null 2>&1; then
            kill -TERM $frontend_pid 2>/dev/null
            sleep 3
            if ps -p $frontend_pid > /dev/null 2>&1; then
                kill -9 $frontend_pid 2>/dev/null
            fi
            log "SUCCESS" "Фронтенд остановлен (PID: $frontend_pid)."
            stopped_any=true
        else
            log "WARNING" "Процесс фронтенда (PID: $frontend_pid) уже не существует."
        fi
        rm -f "$SCRIPT_DIR/.frontend.pid"
    fi
    
    # Проверяем и убиваем процессы, которые могли остаться
    if lsof -i :$API_PORT > /dev/null 2>&1; then
        local pid=$(lsof -t -i :$API_PORT)
        kill -9 $pid 2>/dev/null
        log "WARNING" "Дополнительно остановлен процесс, занимающий порт API (PID: $pid)."
        stopped_any=true
    fi
    
    if lsof -i :$FRONTEND_PORT > /dev/null 2>&1; then
        local pid=$(lsof -t -i :$FRONTEND_PORT)
        kill -9 $pid 2>/dev/null
        log "WARNING" "Дополнительно остановлен процесс, занимающий порт фронтенда (PID: $pid)."
        stopped_any=true
    fi
    
    if [ "$stopped_any" = true ]; then
        log "SUCCESS" "Все приложения остановлены."
    else
        log "INFO" "Не найдено запущенных приложений для остановки."
    fi
    
    return 0
}

# Проверка статуса приложений
check_status() {
    log "INFO" "Проверка статуса приложений..."
    
    local api_running=false
    local frontend_running=false
    
    # Проверяем API
    if lsof -i :$API_PORT > /dev/null 2>&1; then
        local api_pid=$(lsof -t -i :$API_PORT)
        log "SUCCESS" "API работает на порту $API_PORT (PID: $api_pid)"
        
        # Проверяем здоровье API
        if curl -s -f "http://localhost:$API_PORT/health" > /dev/null 2>&1; then
            log "SUCCESS" "API отвечает на запросы здоровья"
        elif curl -s -f "http://localhost:$API_PORT/" > /dev/null 2>&1; then
            log "SUCCESS" "API отвечает на корневые запросы"
        else
            log "WARNING" "API запущен, но не отвечает на HTTP запросы"
        fi
        api_running=true
    else
        log "WARNING" "API не запущен (порт $API_PORT свободен)."
    fi
    
    # Проверяем фронтенд
    if lsof -i :$FRONTEND_PORT > /dev/null 2>&1; then
        local frontend_pid=$(lsof -t -i :$FRONTEND_PORT)
        log "SUCCESS" "Фронтенд работает на порту $FRONTEND_PORT (PID: $frontend_pid)"
        
        # Проверяем здоровье фронтенда
        if curl -s -f "http://localhost:$FRONTEND_PORT/" > /dev/null 2>&1; then
            log "SUCCESS" "Фронтенд отвечает на запросы"
        else
            log "WARNING" "Фронтенд запущен, но не отвечает на HTTP запросы"
        fi
        frontend_running=true
    else
        log "WARNING" "Фронтенд не запущен (порт $FRONTEND_PORT свободен)."
    fi
    
    # Проверяем PID файлы
    if [ -f "$SCRIPT_DIR/.api.pid" ]; then
        local stored_api_pid=$(cat "$SCRIPT_DIR/.api.pid")
        if [ "$api_running" = false ]; then
            log "WARNING" "Найден устаревший PID файл для API (PID: $stored_api_pid)"
            rm -f "$SCRIPT_DIR/.api.pid"
        fi
    fi
    
    if [ -f "$SCRIPT_DIR/.frontend.pid" ]; then
        local stored_frontend_pid=$(cat "$SCRIPT_DIR/.frontend.pid")
        if [ "$frontend_running" = false ]; then
            log "WARNING" "Найден устаревший PID файл для фронтенда (PID: $stored_frontend_pid)"
            rm -f "$SCRIPT_DIR/.frontend.pid"
        fi
    fi
    
    # Общий статус
    if [ "$api_running" = true ] && [ "$frontend_running" = true ]; then
        log "SUCCESS" "Все приложения работают корректно"
    elif [ "$api_running" = true ] || [ "$frontend_running" = true ]; then
        log "WARNING" "Работает только часть приложений"
    else
        log "INFO" "Приложения не запущены"
    fi
    
    return 0
}

# Функция вывода меню
show_menu() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}      УПРАВЛЕНИЕ ПРИЛОЖЕНИЯМИ MOBI_TZ    ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "1. ${YELLOW}Запустить только API (бэкенд)${NC} - Порт: $API_PORT"
    echo -e "2. ${YELLOW}Запустить только фронтенд${NC} - Порт: $FRONTEND_PORT"
    echo -e "3. ${YELLOW}Запустить все в фоновом режиме${NC}"
    echo -e "4. ${YELLOW}Запустить все${NC} (API в фоне, фронтенд активно)"
    echo -e "5. ${YELLOW}Остановить все приложения${NC}"
    echo -e "6. ${YELLOW}Проверить статус приложений${NC}"
    echo -e "7. ${YELLOW}Проверить зависимости системы${NC}"
    echo -e "8. ${CYAN}Показать логи API${NC}"
    echo -e "9. ${CYAN}Показать логи фронтенда${NC}"
    echo -e "0. ${RED}Выход${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "Текущие пути:"
    echo -e "  API: ${CYAN}$API_DIR${NC}"
    echo -e "  Frontend: ${CYAN}$FRONTEND_DIR${NC}"
    echo -e "  Логи: ${CYAN}$SCRIPT_DIR/logs/${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "Выберите опцию: "
}

# Функция для показа логов
show_logs() {
    local service=$1
    local logs_dir="$SCRIPT_DIR/logs"
    
    if [ ! -d "$logs_dir" ]; then
        log "WARNING" "Директория логов не найдена: $logs_dir"
        return 1
    fi
    
    case $service in
        "api")
            local latest_log=$(ls -t "$logs_dir"/api_*.log 2>/dev/null | head -1)
            if [ -n "$latest_log" ]; then
                log "INFO" "Показываем последние логи API: $latest_log"
                echo -e "${BLUE}========== ЛОГИ API ==========${NC}"
                tail -50 "$latest_log"
                echo -e "${BLUE}=============================${NC}"
            else
                log "WARNING" "Логи API не найдены"
            fi
            ;;
        "frontend")
            local latest_log=$(ls -t "$logs_dir"/frontend_*.log 2>/dev/null | head -1)
            if [ -n "$latest_log" ]; then
                log "INFO" "Показываем последние логи фронтенда: $latest_log"
                echo -e "${BLUE}========== ЛОГИ ФРОНТЕНДА ==========${NC}"
                tail -50 "$latest_log"
                echo -e "${BLUE}===================================${NC}"
            else
                log "WARNING" "Логи фронтенда не найдены"
            fi
            ;;
    esac
}

# Функция проверки зависимостей
check_dependencies() {
    log "INFO" "Проверяем наличие необходимых зависимостей..."
    
    # Проверяем наличие скрипта проверки зависимостей
    if [ -f "$SCRIPT_DIR/check_deps.sh" ]; then
        # Запускаем скрипт с перенаправлением вывода
        "$SCRIPT_DIR/check_deps.sh" | grep -E '(ОТСУТСТВУЕТ|НЕАКТИВЕН|НЕСОВМЕСТИМАЯ)'
        
        # Если найдены проблемы, спрашиваем пользователя
        if [ $? -eq 0 ]; then
            log "WARNING" "Обнаружены проблемы с зависимостями."
            echo -e "Подробную информацию можно посмотреть, запустив: ./check_deps.sh"
            echo -e "Хотите продолжить запуск приложения? (y/n)"
            read -r answer
            
            if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
                log "INFO" "Операция отменена. Установите необходимые зависимости перед запуском."
                exit 1
            fi
        else
            log "SUCCESS" "Все необходимые зависимости установлены."
        fi
    else
        log "WARNING" "Не найден скрипт проверки зависимостей (check_deps.sh)."
        echo -e "Продолжаем без проверки зависимостей."
    fi
}

# Основная логика скрипта
main() {
    # Создаем директорию для логов, если она не существует
    mkdir -p "$SCRIPT_DIR/logs"
    
    # Обработка параметров командной строки
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --reset-db)
                RESET_DB=true
                shift
                ;;
            api)
                check_port $API_PORT "API"
                start_api false
                exit 0
                ;;
            frontend)
                check_port $FRONTEND_PORT "Фронтенд"
                start_frontend false
                exit 0
                ;;
            all-background)
                start_all_background
                exit 0
                ;;
            all)
                check_port $API_PORT "API"
                check_port $FRONTEND_PORT "Фронтенд"
                start_api true
                start_frontend false
                exit 0
                ;;
            stop)
                stop_all
                exit 0
                ;;
            status)
                check_status
                exit 0
                ;;
            check-deps)
                if [ -f "$SCRIPT_DIR/check_deps.sh" ]; then
                    "$SCRIPT_DIR/check_deps.sh"
                else
                    log "ERROR" "Не найден скрипт проверки зависимостей (check_deps.sh)."
                fi
                exit 0
                ;;
            show-logs)
                if [ $# -lt 2 ]; then
                    echo "Использование: $0 show-logs <api|frontend>"
                    exit 1
                fi
                show_logs "$2"
                exit 0
                ;;
            *)
                echo "Использование: $0 [--reset-db] [api|frontend|all-background|all|stop|status|check-deps|show-logs <api|frontend>]"
                exit 1
                ;;
        esac
    done
    
    # Если нет аргументов, показываем интерактивное меню
    while true; do
        clear
        show_menu
        read -r option
        
        case $option in
            1)
                check_port $API_PORT "API"
                start_api false
                read -p "Нажмите Enter для продолжения..."
                ;;
            2)
                check_port $FRONTEND_PORT "Фронтенд"
                start_frontend false
                read -p "Нажмите Enter для продолжения..."
                ;;
            3)
                start_all_background
                read -p "Нажмите Enter для продолжения..."
                ;;
            4)
                check_port $API_PORT "API"
                check_port $FRONTEND_PORT "Фронтенд"
                
                log "INFO" "Запускаем API в фоновом режиме..."
                start_api true
                
                log "INFO" "Запускаем фронтенд..."
                start_frontend false
                read -p "Нажмите Enter для продолжения..."
                ;;
            5)
                stop_all
                read -p "Нажмите Enter для продолжения..."
                ;;
            6)
                check_status
                read -p "Нажмите Enter для продолжения..."
                ;;
            7)
                if [ -f "$SCRIPT_DIR/check_deps.sh" ]; then
                    log "INFO" "Запуск проверки зависимостей..."
                    "$SCRIPT_DIR/check_deps.sh"
                else
                    log "ERROR" "Не найден скрипт проверки зависимостей (check_deps.sh)."
                fi
                read -p "Нажмите Enter для продолжения..."
                ;;
            8)
                show_logs api
                read -p "Нажмите Enter для продолжения..."
                ;;
            9)
                show_logs frontend
                read -p "Нажмите Enter для продолжения..."
                ;;
            0)
                log "SUCCESS" "До свидания!"
                exit 0
                ;;
            *)
                log "ERROR" "Неверный выбор. Пожалуйста, выберите опцию из меню."
                read -p "Нажмите Enter для продолжения..."
                ;;
        esac
    done
}

# Запускаем основную функцию
main "$@"
