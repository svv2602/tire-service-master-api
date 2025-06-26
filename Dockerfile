# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t api .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name api api

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
FROM ruby:3.3.7-alpine

# Устанавливаем системные зависимости
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    postgresql-client \
    git \
    curl \
    tzdata \
    bash \
    nodejs \
    npm \
    imagemagick \
    vips-dev \
    shared-mime-info

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем Gemfile и Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Устанавливаем bundler и зависимости
RUN gem install bundler:2.5.23 && \
    bundle config set --local deployment 'false' && \
    bundle config set --local without 'production' && \
    bundle install --jobs 4 --retry 3

# Копируем весь код приложения
COPY . .

# Создаем директории для логов и временных файлов
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log && \
    chmod -R 755 tmp log

# Устанавливаем права доступа
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

# Переключаемся на пользователя приложения
USER appuser

# Открываем порт 8000
EXPOSE 8000

# Команда по умолчанию (может быть переопределена в docker-compose.yml)
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "8000"]
