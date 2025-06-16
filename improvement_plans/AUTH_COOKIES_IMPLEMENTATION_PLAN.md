# План перехода с localStorage на HttpOnly куки

## Обоснование изменений

Текущая реализация аутентификации использует хранение JWT токенов в localStorage, что создает следующие проблемы безопасности:

1. **Уязвимость к XSS-атакам**: JavaScript имеет доступ к localStorage, что делает токены уязвимыми при XSS-атаках
2. **Отсутствие контроля со стороны сервера**: Сервер не может управлять жизненным циклом токенов
3. **Отсутствие дополнительных мер защиты**: Нет возможности использовать флаги HttpOnly, Secure и SameSite

Переход на HttpOnly куки повысит безопасность системы аутентификации, защитит токены от кражи через XSS и даст серверу больше контроля.

## План реализации

### 1. Изменения на бэкенде

#### 1.1. Обновление контроллера аутентификации

```ruby
# app/controllers/api/v1/auth_controller.rb

def login
  user = User.find_by(email: params[:email])
  
  if user&.authenticate(params[:password])
    access_token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
    refresh_token = Auth::JsonWebToken.encode_refresh_token(user_id: user.id)
    
    # Установка куки для refresh токена (HttpOnly)
    cookies.encrypted[:refresh_token] = {
      value: refresh_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :strict,
      expires: 30.days.from_now
    }
    
    # Возвращаем только access токен в JSON ответе
    render json: {
      user: UserSerializer.new(user),
      access_token: access_token
    }, status: :ok
  else
    render json: { error: 'Неверный email или пароль' }, status: :unauthorized
  end
end

def refresh
  # Получаем refresh токен из куки вместо заголовка
  refresh_token = cookies.encrypted[:refresh_token]
  
  if refresh_token.blank?
    render json: { error: 'Refresh token отсутствует' }, status: :unauthorized
    return
  end
  
  begin
    # Проверяем и обновляем токен
    access_token = Auth::JsonWebToken.refresh_access_token(refresh_token)
    
    render json: { access_token: access_token }, status: :ok
  rescue Auth::TokenExpiredError, Auth::TokenInvalidError => e
    # Удаляем куки при ошибке
    cookies.delete(:refresh_token)
    render json: { error: e.message }, status: :unauthorized
  end
end

def logout
  # Удаляем куки при выходе
  cookies.delete(:refresh_token)
  render json: { message: 'Выход выполнен успешно' }, status: :ok
end
```

#### 1.2. Настройка CORS для работы с куки

```ruby
# config/initializers/cors.rb

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:3008', 'https://your-production-domain.com'
    
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true # Важно для работы с куки в CORS
  end
end
```

#### 1.3. Обновление конфигурации Rails для работы с куки

```ruby
# config/application.rb

config.middleware.use ActionDispatch::Cookies
config.middleware.use ActionDispatch::Session::CookieStore, key: '_tire_service_session'
```

### 2. Изменения на фронтенде

#### 2.1. Обновление axios конфигурации

```typescript
// src/api/api.ts

const api = axios.create({
  baseURL: config.API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true // Важно для отправки и получения куки
});
```

#### 2.2. Обновление хранилища Redux

```typescript
// src/store/slices/authSlice.ts

// Удаляем работу с localStorage
const authSlice = createSlice({
  name: 'auth',
  initialState: {
    user: null,
    accessToken: null,
    isAuthenticated: false,
    isLoading: false,
    error: null
  },
  reducers: {
    // Редьюсеры без localStorage
  },
  extraReducers: (builder) => {
    builder
      .addCase(login.fulfilled, (state, action) => {
        state.user = action.payload.user;
        state.accessToken = action.payload.access_token;
        state.isAuthenticated = true;
        state.isLoading = false;
        // Не сохраняем в localStorage
      })
      // Другие обработчики
  }
});
```

#### 2.3. Обновление API для аутентификации

```typescript
// src/api/auth.api.ts

export const authApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    login: builder.mutation<LoginResponse, LoginRequest>({
      query: (credentials) => ({
        url: '/auth/login',
        method: 'POST',
        body: credentials,
      }),
    }),
    
    refresh: builder.mutation<RefreshResponse, void>({
      query: () => ({
        url: '/auth/refresh',
        method: 'POST',
        // Не нужно отправлять refresh токен в теле запроса
      }),
    }),
    
    logout: builder.mutation<LogoutResponse, void>({
      query: () => ({
        url: '/auth/logout',
        method: 'POST',
        // Не нужно отправлять токен в теле запроса
      }),
    }),
  }),
});
```

#### 2.4. Обновление перехватчиков запросов

```typescript
// src/api/interceptors.ts

// Перехватчик для добавления токена в заголовки
api.interceptors.request.use(
  (config) => {
    const state = store.getState();
    const token = state.auth.accessToken;
    
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    
    return config;
  },
  (error) => Promise.reject(error)
);

// Перехватчик для обработки ошибок аутентификации
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    
    // Если ошибка 401 и запрос не на обновление токена
    if (error.response?.status === 401 && !originalRequest._retry && 
        !originalRequest.url.includes('auth/refresh')) {
      originalRequest._retry = true;
      
      try {
        // Запрос на обновление токена (refresh токен будет отправлен автоматически в куки)
        const response = await store.dispatch(authApi.endpoints.refresh.initiate()).unwrap();
        
        // Обновляем токен в Redux
        store.dispatch(setAccessToken(response.access_token));
        
        // Повторяем оригинальный запрос с новым токеном
        originalRequest.headers.Authorization = `Bearer ${response.access_token}`;
        return api(originalRequest);
      } catch (refreshError) {
        // Если не удалось обновить токен, выходим из системы
        store.dispatch(logout());
        return Promise.reject(refreshError);
      }
    }
    
    return Promise.reject(error);
  }
);
```

### 3. Тестирование и отладка

#### 3.1. Тестовые сценарии

1. **Базовая аутентификация**
   - Вход в систему
   - Проверка наличия куки refresh_token (HttpOnly)
   - Проверка работы защищенных маршрутов

2. **Обновление токена**
   - Имитация истечения срока действия access токена
   - Проверка автоматического обновления через refresh токен
   - Проверка продолжения работы после обновления

3. **Выход из системы**
   - Проверка удаления куки при выходе
   - Проверка перенаправления на страницу входа

4. **Безопасность**
   - Проверка недоступности refresh токена через JavaScript
   - Проверка работы CORS с учетными данными

#### 3.2. Отладка

- Использовать вкладку Application > Cookies в DevTools для проверки куки
- Проверить заголовки запросов на наличие Authorization
- Проверить заголовки ответов на наличие Set-Cookie

### 4. Миграция существующих пользователей

1. **Плавный переход**
   - Временно поддерживать оба метода аутентификации
   - При обнаружении токена в localStorage, переносить его в куки

2. **Принудительный выход**
   - После полного развертывания, вынудить пользователей повторно войти в систему
   - Очистить localStorage от старых токенов

### 5. Документация

1. **Для разработчиков**
   - Обновить документацию по API аутентификации
   - Описать новый процесс работы с токенами

2. **Для пользователей**
   - Уведомить о необходимости повторного входа (при необходимости)
   - Объяснить улучшения безопасности

## График реализации

1. **Разработка и тестирование на dev-окружении**: 1-2 недели
2. **Тестирование на staging-окружении**: 1 неделя
3. **Развертывание на production**: 1 день
4. **Мониторинг и устранение проблем**: 1 неделя

## Риски и их снижение

1. **Проблемы с CORS**
   - Тщательное тестирование на разных окружениях
   - Подготовка плана отката изменений

2. **Несовместимость с некоторыми браузерами**
   - Тестирование на всех поддерживаемых браузерах
   - Добавление fallback механизма для проблемных браузеров

3. **Проблемы с существующими сессиями**
   - Плавная миграция с поддержкой обоих методов
   - Мониторинг количества ошибок аутентификации после развертывания 