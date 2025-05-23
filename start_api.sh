#!/bin/bash

# Переходим в директорию API
cd /home/snisar/mobi_tz/tire-service-master-api

# Проверяем наличие файла tmp/pids/server.pid
if [ -f tmp/pids/server.pid ]; then
  echo "Удаляем старый PID файл..."
  rm tmp/pids/server.pid
fi

# Запускаем Rails сервер на порту 8000
echo "Запускаем Rails API на порту 8000..."
bundle exec rails server -p 8000 