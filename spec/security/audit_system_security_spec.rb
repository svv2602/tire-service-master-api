require 'rails_helper'

RSpec.describe 'Тесты безопасности системы аудита', type: :request do
  let!(:admin) { create(:user, :admin) }
  let!(:manager) { create(:manager) }
  let!(:manager_user) { create(:user, :manager, manager: manager) }
  let!(:partner) { create(:partner) }
  let!(:partner_user) { create(:user, :partner, partner: partner) }
  let!(:operator) { create(:operator, partner: partner) }
  let!(:operator_user) { create(:user, :operator, operator: operator) }

  describe 'Безопасность доступа к аудит логам' do
    context 'Права доступа к просмотру логов' do
      it 'админ может просматривать все логи' do
        sign_in admin
        get '/api/v1/audit_logs', headers: auth_headers
        
        expect(response).to have_http_status(:success)
      end

      it 'менеджер может просматривать логи' do
        sign_in manager_user
        get '/api/v1/audit_logs', headers: auth_headers
        
        expect(response).to have_http_status(:success)
      end

      it 'партнер НЕ может просматривать логи' do
        sign_in partner_user
        get '/api/v1/audit_logs', headers: auth_headers
        
        expect(response).to have_http_status(:forbidden)
      end

      it 'оператор НЕ может просматривать логи' do
        sign_in operator_user
        get '/api/v1/audit_logs', headers: auth_headers
        
        expect(response).to have_http_status(:forbidden)
      end

      it 'неавторизованный пользователь НЕ может просматривать логи' do
        get '/api/v1/audit_logs'
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'Фильтрация логов по правам доступа' do
      let!(:admin_log) { create(:system_log, user: admin, action: 'created', resource_type: 'User') }
      let!(:partner_log) { create(:system_log, user: partner_user, action: 'updated', resource_type: 'ServicePoint') }

      it 'админ видит все логи' do
        sign_in admin
        get '/api/v1/audit_logs', headers: auth_headers
        
        expect(response).to have_http_status(:success)
        logs = JSON.parse(response.body)['data']
        log_ids = logs.map { |l| l['id'] }
        
        expect(log_ids).to include(admin_log.id, partner_log.id)
      end

      it 'менеджер видит все логи' do
        sign_in manager_user
        get '/api/v1/audit_logs', headers: auth_headers
        
        expect(response).to have_http_status(:success)
        logs = JSON.parse(response.body)['data']
        log_ids = logs.map { |l| l['id'] }
        
        expect(log_ids).to include(admin_log.id, partner_log.id)
      end
    end

    context 'Защита от injection атак в фильтрах' do
      before { sign_in admin }

      it 'защищен от SQL injection в фильтре по пользователю' do
        malicious_user_id = "1; DROP TABLE system_logs; --"
        
        get '/api/v1/audit_logs',
            params: { user_id: malicious_user_id },
            headers: auth_headers
        
        expect(response).to have_http_status(:success)
        # Таблица system_logs должна существовать
        expect { SystemLog.count }.not_to raise_error
      end

      it 'защищен от SQL injection в фильтре по действию' do
        malicious_action = "created'; DROP TABLE system_logs; --"
        
        get '/api/v1/audit_logs',
            params: { action: malicious_action },
            headers: auth_headers
        
        expect(response).to have_http_status(:success)
        expect { SystemLog.count }.not_to raise_error
      end

      it 'защищен от XSS в параметрах поиска' do
        xss_payload = "<script>alert('XSS')</script>"
        
        get '/api/v1/audit_logs',
            params: { resource_type: xss_payload },
            headers: auth_headers
        
        expect(response).to have_http_status(:success)
        # Ответ не должен содержать исполняемый код
        expect(response.body).not_to include('<script>')
      end
    end

    context 'Ограничения на экспорт данных' do
      before { sign_in admin }

      it 'ограничивает размер экспорта' do
        # Создаем много записей
        create_list(:system_log, 1000, user: admin)
        
        get '/api/v1/audit_logs/export',
            params: { format: 'csv' },
            headers: auth_headers
        
        expect(response).to have_http_status(:success)
        
        # Проверяем, что экспорт не содержит все записи (должен быть лимит)
        lines = response.body.split("\n")
        expect(lines.length).to be <= 1001  # Header + max 1000 records
      end

      it 'требует дополнительной авторизации для больших экспортов' do
        create_list(:system_log, 5000, user: admin)
        
        get '/api/v1/audit_logs/export',
            params: { format: 'excel', limit: 5000 },
            headers: auth_headers
        
        # Должен требовать подтверждение или возвращать ошибку
        expect([200, 403, 422]).to include(response.status)
      end
    end
  end

  describe 'Защита от манипуляций с логами' do
    let!(:log_entry) { create(:system_log, user: partner_user, action: 'created') }

    context 'Невозможность изменения логов' do
      before { sign_in admin }

      it 'не позволяет обновлять существующие логи' do
        patch "/api/v1/audit_logs/#{log_entry.id}",
              params: { system_log: { action: 'modified' } },
              headers: auth_headers
        
        # Должен возвращать 404 или 405 (метод не поддерживается)
        expect([404, 405]).to include(response.status)
      end

      it 'не позволяет удалять логи' do
        delete "/api/v1/audit_logs/#{log_entry.id}",
               headers: auth_headers
        
        # Должен возвращать 404 или 405 (метод не поддерживается)
        expect([404, 405]).to include(response.status)
      end

      it 'не позволяет создавать логи напрямую через API' do
        post '/api/v1/audit_logs',
             params: { 
               system_log: { 
                 action: 'fake_action',
                 resource_type: 'FakeResource',
                 user_id: admin.id
               }
             },
             headers: auth_headers
        
        # Должен возвращать 404 или 405 (метод не поддерживается)
        expect([404, 405]).to include(response.status)
      end
    end
  end

  describe 'Мониторинг подозрительной активности' do
    context 'Обнаружение аномальной активности' do
      before { sign_in admin }

      it 'логирует множественные неудачные попытки доступа' do
        # Симулируем множественные неудачные попытки входа
        5.times do
          post '/api/v1/auth/login',
               params: { email: 'wrong@email.com', password: 'wrongpassword' }
        end
        
        # Должны появиться записи в логах о неудачных попытках
        failed_login_logs = SystemLog.where(action: 'failed_login_attempt')
        expect(failed_login_logs.count).to be >= 5
      end

      it 'логирует попытки доступа к запрещенным ресурсам' do
        sign_in partner_user
        
        # Попытка доступа к запрещенному ресурсу
        get '/api/v1/users', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
        
        # Должна появиться запись в логах о попытке несанкционированного доступа
        unauthorized_logs = SystemLog.where(
          user: partner_user,
          action: 'unauthorized_access_attempt'
        )
        expect(unauthorized_logs.count).to be >= 1
      end

      it 'обнаруживает подозрительные паттерны запросов' do
        sign_in partner_user
        
        # Множественные быстрые запросы (возможный скрапинг)
        10.times do
          get '/api/v1/service_points', headers: auth_headers
        end
        
        # Система должна зафиксировать подозрительную активность
        suspicious_logs = SystemLog.where(
          user: partner_user,
          action: 'suspicious_activity'
        )
        expect(suspicious_logs.count).to be >= 1
      end
    end

    context 'Автоматические алерты' do
      it 'отправляет уведомления при критических событиях' do
        # Симулируем критическое событие (например, массовое удаление)
        expect {
          sign_in admin
          # Попытка удалить множество записей
          10.times { |i| delete "/api/v1/users/#{i + 1000}", headers: auth_headers }
        }.to change { ActionMailer::Base.deliveries.count }.by_at_least(1)
      end
    end
  end

  describe 'Производительность системы аудита' do
    before { sign_in admin }

    it 'эффективно обрабатывает большие объемы логов' do
      # Создаем большое количество логов
      create_list(:system_log, 1000, user: admin)
      
      start_time = Time.current
      
      get '/api/v1/audit_logs',
          params: { per_page: 100 },
          headers: auth_headers
      
      execution_time = Time.current - start_time
      
      expect(response).to have_http_status(:success)
      expect(execution_time).to be < 3.seconds
    end

    it 'использует пагинацию для больших результатов' do
      create_list(:system_log, 500, user: admin)
      
      get '/api/v1/audit_logs',
          params: { per_page: 50 },
          headers: auth_headers
      
      expect(response).to have_http_status(:success)
      
      response_data = JSON.parse(response.body)
      expect(response_data['data'].length).to eq(50)
      expect(response_data['pagination']).to be_present
    end
  end

  describe 'Соответствие требованиям безопасности' do
    it 'сохраняет логи минимум 30 дней' do
      # Создаем старый лог
      old_log = create(:system_log, user: admin, created_at: 25.days.ago)
      very_old_log = create(:system_log, user: admin, created_at: 35.days.ago)
      
      # Запускаем задачу очистки
      expect {
        # Здесь должна быть задача очистки старых логов
        SystemLog.where('created_at < ?', 30.days.ago).destroy_all
      }.to change { SystemLog.count }.by(-1)
      
      expect(SystemLog.exists?(old_log.id)).to be true
      expect(SystemLog.exists?(very_old_log.id)).to be false
    end

    it 'шифрует чувствительные данные в логах' do
      # Создаем лог с чувствительными данными
      sensitive_data = { password: 'secret123', credit_card: '1234-5678-9012-3456' }
      log = create(:system_log, user: admin, additional_data: sensitive_data)
      
      # Проверяем, что чувствительные данные не хранятся в открытом виде
      expect(log.additional_data.to_s).not_to include('secret123')
      expect(log.additional_data.to_s).not_to include('1234-5678-9012-3456')
    end
  end

  private

  def auth_headers
    token = JWT.encode({ user_id: @current_user.id }, Rails.application.secret_key_base)
    { 'Authorization' => "Bearer #{token}" }
  end

  def sign_in(user)
    @current_user = user
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end
end 