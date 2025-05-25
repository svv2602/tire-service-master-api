require 'rails_helper'

RSpec.describe "API V1 Users", type: :request do
  include RequestSpecHelper
  
  # Тестовые данные
  let(:admin_role) { UserRole.find_or_create_by(name: 'admin') { |role| role.description = 'Administrator role with full access' } }
  let(:admin_user) { create(:user, role: admin_role) }
  let(:admin_headers) { authenticate_user(admin_user) }
  
  # Тест для GET /api/v1/users/me
  describe "GET /api/v1/users/me" do
    context 'when authenticated' do
      before do
        get '/api/v1/users/me', headers: admin_headers
      end
      
      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
      
      it 'returns the current user data' do
        expect(json).not_to be_empty
        expect(json['id']).to eq(admin_user.id)
        expect(json['email']).to eq(admin_user.email)
        expect(json['role']).to eq('admin')
      end
    end
    
    context 'when not authenticated' do
      before do
        get '/api/v1/users/me'
      end
      
      it 'returns status code 401' do
        expect(response).to have_http_status(401)
      end
      
      it 'returns an unauthorized message' do
        expect(json['error']).to match(/не авторизован|unauthorized/i)
      end
    end
  end
end
