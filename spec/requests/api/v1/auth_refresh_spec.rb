require 'rails_helper'

RSpec.describe 'Auth Refresh Token', type: :request do
  describe 'POST /api/v1/auth/refresh' do
    let(:user) { create(:user, :with_admin_role) }
    let(:token_service) { Auth::JsonWebToken }
    
    context 'when refresh token is valid' do
      it 'returns new access and refresh tokens' do
        # Создаем refresh токен
        refresh_token = token_service.encode_refresh_token(user_id: user.id)
        
        # Отправляем запрос на обновление токена
        post '/api/v1/auth/refresh', params: { refresh_token: refresh_token }
        
        # Проверяем ответ
        expect(response).to have_http_status(:ok)
        
        json = JSON.parse(response.body)
        expect(json).to have_key('tokens')
        expect(json['tokens']).to have_key('access')
        expect(json['tokens']).to have_key('refresh')
        
        # Проверяем, что новые токены действительны
        new_access_token = json['tokens']['access']
        decoded_access = token_service.decode(new_access_token)
        expect(decoded_access[:user_id]).to eq(user.id)
        expect(decoded_access[:token_type]).to eq('access')
      end
    end
    
    context 'when refresh token is invalid' do
      it 'returns unauthorized for invalid token' do
        # Отправляем запрос с невалидным токеном
        post '/api/v1/auth/refresh', params: { refresh_token: 'invalid_token' }
        
        # Проверяем ответ
        expect(response).to have_http_status(:unauthorized)
        
        json = JSON.parse(response.body)
        expect(json).to have_key('error')
      end
      
      it 'returns unauthorized when refresh token is missing' do
        # Отправляем запрос без токена
        post '/api/v1/auth/refresh'
        
        # Проверяем ответ
        expect(response).to have_http_status(:unauthorized)
        
        json = JSON.parse(response.body)
        expect(json).to have_key('error')
      end
    end
  end
end 