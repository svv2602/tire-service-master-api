# Security Hardening Skill (Rails API)

Этот скилл содержит паттерны и решения для security hardening Rails API приложений.

---

## Rate Limiting (Rack::Attack)

### Установка
```ruby
# Gemfile
gem 'rack-attack'
```

### Конфигурация
**File**: `config/initializers/rack_attack.rb`

```ruby
class Rack::Attack
  # Cache store (Redis в production)
  if Rails.env.production? && ENV["REDIS_URL"]
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
  else
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  # Safelist localhost в development
  safelist("allow-localhost") do |req|
    (Rails.env.development? || Rails.env.test?) && req.ip == "127.0.0.1"
  end

  # Login: 5 req/min per IP
  throttle("login/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  # Login: 5 req/min per email
  throttle("login/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      begin
        body = JSON.parse(req.body.read)
        req.body.rewind
        body["email"]&.downcase&.strip
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Password reset: 3 req/5min
  throttle("password_reset/ip", limit: 3, period: 5.minutes) do |req|
    req.ip if req.path == "/api/v1/auth/password_reset" && req.post?
  end

  # Registration: 3 req/min
  throttle("registration/ip", limit: 3, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/register" && req.post?
  end

  # General API: 300 req/min
  throttle("api/ip", limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Fail2ban: 1hr ban after 10 failed attempts
  blocklist("fail2ban/login") do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 10, findtime: 1.minute, bantime: 1.hour) do
      req.path == "/api/v1/auth/login" && req.post?
    end
  end

  # Custom JSON responses
  self.throttled_responder = ->(request) {
    match_data = request.env["rack.attack.match_data"]
    retry_after = match_data[:period] - (match_data[:epoch_time] % match_data[:period])
    [429, {"Content-Type" => "application/json", "Retry-After" => retry_after.to_s},
     [{error: "Too Many Requests", retry_after: retry_after}.to_json]]
  }

  self.blocklisted_responder = ->(request) {
    [403, {"Content-Type" => "application/json"},
     [{error: "Forbidden", message: "IP temporarily blocked"}.to_json]]
  }
end
```

---

## CSRF Protection (Cookie Auth)

### Backend

**ApplicationController** - установка CSRF cookie:
```ruby
class ApplicationController < ActionController::API
  include ActionController::RequestForgeryProtection

  before_action :set_csrf_cookie

  private

  def set_csrf_cookie
    cookies['XSRF-TOKEN'] = {
      value: form_authenticity_token,
      same_site: :lax,
      secure: Rails.env.production?,
      httponly: false,  # JS должен читать
      path: '/'
    }
  end
end
```

**BaseController** - проверка CSRF:
```ruby
class Api::V1::BaseController < ApplicationController
  before_action :verify_csrf_for_cookie_auth

  private

  def verify_csrf_for_cookie_auth
    return if request.get? || request.head? || request.options?
    return if request.headers['Authorization'].present?  # Skip для token auth

    if cookies[:access_token].present?
      csrf_token = request.headers['X-XSRF-TOKEN']
      unless valid_authenticity_token?(session, csrf_token)
        render json: { error: 'Invalid CSRF token' }, status: :forbidden
      end
    end
  end
end
```

**CSRF Endpoint**:
```ruby
# app/controllers/api/v1/csrf_controller.rb
module Api::V1
  class CsrfController < ApplicationController
    skip_before_action :authenticate_request, raise: false

    def show
      render json: { csrf_token: form_authenticity_token }
    end
  end
end

# routes.rb
get 'csrf', to: 'csrf#show'
```

### Frontend (RTK Query)

```typescript
// src/api/baseQuery.ts
const getCookie = (name: string): string | null => {
  const matches = document.cookie.match(
    new RegExp('(?:^|; )' + name.replace(/([.$?*|{}()[\]\\/+^])/g, '\\$1') + '=([^;]*)')
  );
  return matches ? decodeURIComponent(matches[1]) : null;
};

export const baseQuery = fetchBaseQuery({
  baseUrl: `${config.API_URL}${config.API_PREFIX}/`,
  prepareHeaders: (headers, { getState }) => {
    const accessToken = (getState() as RootState).auth?.accessToken;

    if (accessToken) {
      headers.set('authorization', `Bearer ${accessToken}`);
    } else {
      // CSRF только для cookie auth
      const csrfToken = getCookie('XSRF-TOKEN');
      if (csrfToken) headers.set('X-XSRF-TOKEN', csrfToken);
    }
    return headers;
  },
  credentials: 'include',
});
```

---

## HTML Content Sanitization

### Concern
**File**: `app/models/concerns/content_sanitizable.rb`

```ruby
module ContentSanitizable
  extend ActiveSupport::Concern

  ALLOWED_TAGS = %w[
    p br div span strong b em i u s strike
    h1 h2 h3 h4 h5 h6 ul ol li a img
    table thead tbody tfoot tr th td
    blockquote pre code hr sub sup
  ].freeze

  ALLOWED_ATTRIBUTES = %w[
    href target rel src alt title width height
    class id style colspan rowspan
  ].freeze

  included do
    class_attribute :sanitizable_fields, default: []
    before_save :sanitize_content_fields
  end

  class_methods do
    def sanitize_fields(*fields)
      self.sanitizable_fields = fields.map(&:to_sym)
    end
  end

  private

  def sanitize_content_fields
    sanitizable_fields.each do |field|
      next unless respond_to?(field)
      value = send(field)
      next if value.blank?
      send("#{field}=", sanitize_html(value))
    end
  end

  def sanitize_html(content)
    sanitizer = Rails::Html::SafeListSanitizer.new
    sanitized = sanitizer.sanitize(content, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)

    # Remove dangerous URLs
    sanitized = sanitized.gsub(/href\s*=\s*["']?\s*javascript:[^"'>]*/i, 'href="#removed"')
    sanitized = sanitized.gsub(/src\s*=\s*["']?\s*javascript:[^"'>]*/i, 'src=""')

    # Remove event handlers
    sanitized.gsub(/\s+on\w+\s*=\s*["'][^"']*["']/i, '')
  end
end
```

### Использование
```ruby
class Article < ApplicationRecord
  include ContentSanitizable
  sanitize_fields :content, :content_uk
end
```

---

## Security Headers

**File**: `config/application.rb`

```ruby
config.action_dispatch.default_headers = {
  'X-Frame-Options' => 'DENY',
  'X-Content-Type-Options' => 'nosniff',
  'X-XSS-Protection' => '1; mode=block',
  'X-Download-Options' => 'noopen',
  'X-Permitted-Cross-Domain-Policies' => 'none',
  'Referrer-Policy' => 'strict-origin-when-cross-origin',
  'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()'
}
```

**File**: `config/initializers/secure_headers.rb`

```ruby
Rails.application.configure do
  if Rails.env.production?
    config.force_ssl = true
    config.ssl_options = {
      redirect: { exclude: ->(request) { request.path.start_with?('/health') } },
      hsts: { subdomains: true, preload: true, expires: 1.year }
    }
  end
  config.action_dispatch.cookies_same_site_protection = :lax
end

Rails.application.config.content_security_policy do |policy|
  policy.default_src :none
  policy.frame_ancestors :none
  policy.form_action :self
  policy.base_uri :self
end
```

---

## Secure Logging

### Filter Parameters
**File**: `config/initializers/filter_parameter_logging.rb`

```ruby
Rails.application.config.filter_parameters += [
  :passw, :password, :password_confirmation,
  :token, :access_token, :refresh_token,
  :secret, :api_key, :authorization,
  :bearer, :jwt, :auth, :credential, :private_key,
  :email, :ssn, :cvv, :cvc,
  :_key, :crypt, :salt, :certificate, :otp
]
```

### Logging Pattern
```ruby
# ❌ Плохо - логирует значение токена
Rails.logger.debug "Token: #{token}"

# ✅ Хорошо - логирует только наличие
Rails.logger.debug "Auth: token=#{token.present?}"
Rails.logger.debug "Auth: authenticated user_id=#{user.id}"
```

---

## Brakeman Security Scan

### Команды
```bash
gem install brakeman
brakeman -A --no-pager           # Полный скан
brakeman -A --no-pager -w1       # Только HIGH/MEDIUM
```

### Частые исправления

**SQL Injection:**
```ruby
# ❌ Плохо
Model.exists?(params[:id])
connection.execute("SELECT * FROM #{table}")

# ✅ Хорошо
Model.exists?(id: params[:id].to_i)
connection.execute("SELECT * FROM #{connection.quote_table_name(table)}")
connection.sanitize_sql_array(["SELECT setval(?, ?)", name, value])
```

---

## CORS Configuration

**File**: `config/initializers/cors.rb`

```ruby
def cors_allowed_origins
  if Rails.env.production?
    ENV['ALLOWED_ORIGINS']&.split(',')&.map(&:strip) || [
      'https://your-domain.com'
    ]
  else
    ['localhost:3000', 'localhost:5173', '127.0.0.1:3000']
  end
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*cors_allowed_origins)
    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 600
  end
end
```

---

## Checklist

- [ ] Rate limiting (Rack::Attack)
- [ ] CSRF protection for cookie auth
- [ ] Security headers (X-Frame-Options, CSP, HSTS)
- [ ] Secure logging (no tokens in logs)
- [ ] HTML sanitization for user content
- [ ] Brakeman scan: 0 HIGH issues
- [ ] CORS restricted in production
- [ ] Force SSL in production
