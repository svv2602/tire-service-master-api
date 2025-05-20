#!/bin/bash

# Устанавливаем переменные окружения
export RAILS_ENV=development
export PORT=8000

# Удаляем файл сервера, если он существует
if [ -f tmp/pids/server.pid ]; then
  rm tmp/pids/server.pid
fi

# Обновляем гемы, если нужно
bundle check || bundle install

# Запускаем миграции, если нужно
bundle exec rails db:migrate

# Заполняем базу данных начальными данными
bundle exec rails db:seed

# Запускаем сервер API
bundle exec rails server -p $PORT -b 0.0.0.0 