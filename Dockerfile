# syntax=docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
FROM ruby:3.3.7-alpine

# Устанавливаем системные зависимости
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    yaml-dev \
    postgresql-dev \
    git \
    && apk add --no-cache \
    postgresql-client \
    curl \
    tzdata \
    bash \
    nodejs \
    npm \
    imagemagick \
    vips-dev \
    shared-mime-info \
    ca-certificates

# Устанавливаем рабочую директорию
WORKDIR /app

# Создаем пользователя приложения
#RUN addgroup -g 1000 -S appgroup && \
#    adduser -u 1000 -S appuser -G appgroup

# Копируем Gemfile и Gemfile.lock
#COPY --chown=appuser:appgroup Gemfile Gemfile.lock ./

# Устанавливаем bundler и зависимости
RUN gem install bundler:2.5.23 && \
    bundle config set --local deployment 'false' && \
    bundle config set --local without 'production' && \
    bundle install --jobs 4 --retry 3 && \
    bundle clean --force

# Удаляем build зависимости для уменьшения размера образа
RUN apk del .build-deps

# Копируем весь код приложения
# COPY --chown=appuser:appgroup . .

# Создаем директории для логов и временных файлов
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log && \
    chmod -R 755 tmp log && \
    chown -R root:root tmp log

# Переключаемся на пользователя приложения
USER root

# Открываем порт 8000
EXPOSE 8000

# Добавляем health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8000/api/v1/health || exit 1

# Команда по умолчанию
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "8000"]
