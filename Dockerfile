# Многоэтапная сборка для Rails API
FROM ruby:3.3.7-alpine AS base

# Устанавливаем системные зависимости
RUN apk update && apk add --no-cache \
    build-base \
    postgresql-dev \
    postgresql-client \
    curl \
    tzdata \
    git \
    nodejs \
    npm \
    yaml-dev \
    bash

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем Gemfile и Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Устанавливаем bundler и gems
RUN gem install bundler:2.5.23 && \
    bundle config set --local path 'vendor/bundle' && \
    bundle install --jobs $(nproc) --retry 3

# Копируем исходный код приложения
COPY . .

# Устанавливаем права доступа
RUN chmod +x bin/rails bin/docker-entrypoint

# Создаем пользователя для безопасности
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Создаем необходимые директории
RUN mkdir -p tmp/pids log && \
    chown -R appuser:appgroup /app

# Переключаемся на пользователя
USER appuser

# Открываем порт
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/api/v1/health || exit 1

# Entrypoint runs db:migrate automatically before starting the server
ENTRYPOINT ["bin/docker-entrypoint"]

# Default command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "8000"]
