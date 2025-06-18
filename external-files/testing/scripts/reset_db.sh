#!/bin/bash
# Скрипт для полного сброса и заполнения базы данных

echo "=== ПОЛНЫЙ СБРОС И ЗАПОЛНЕНИЕ БАЗЫ ДАННЫХ ==="
echo "Этот скрипт выполнит полный сброс базы данных и заполнит ее тестовыми данными."
echo "ВНИМАНИЕ: Все данные в базе будут удалены!"
echo ""

read -p "Вы уверены, что хотите продолжить? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Операция отменена."
    exit 1
fi

echo ""
echo "Начинаем процесс..."

# Сбрасываем базу данных
echo "1. Сбрасываем базу данных..."
bundle exec rails db:drop db:create db:migrate

# Загружаем данные
echo "2. Загружаем тестовые данные..."
bundle exec rails runner "load 'db/seeds/reset_and_seed_all.rb'"

echo ""
echo "=== ПРОЦЕСС ЗАВЕРШЕН ==="
echo "База данных успешно сброшена и заполнена тестовыми данными."
echo ""
echo "Учетные данные для входа:"
echo "Админ:    admin@test.com / admin123"
echo "Менеджер: manager@test.com / manager123"
echo "Оператор: operator@test.com / operator123"
echo "Партнер:  partner@test.com / partner123"
echo "Клиент:   client@test.com / client123"
echo ""
echo "Для запуска приложения используйте скрипт start.sh" 