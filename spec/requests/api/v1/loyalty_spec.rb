require 'rails_helper'

RSpec.describe 'Loyalty API', type: :request do
  let(:user) { create(:client_user) }
  let(:headers) { valid_headers(user) }

  describe 'GET /api/v1/loyalty/balance' do
    context 'when authenticated' do
      it 'returns loyalty balance for a new user' do
        get '/api/v1/loyalty/balance', headers: headers

        expect(response).to have_http_status(:ok)
        expect(json['success']).to be true
        expect(json['data']['points']).to eq(0)
        expect(json['data']['level']).to eq('bronze')
        expect(json['data']['level_progress']).to eq(0)
        expect(json['data']['points_to_next_level']).to eq(100)
        expect(json['data']['next_level']).to eq('silver')
      end

      it 'returns correct balance for existing account' do
        create(:loyalty_account, user: user, points: 250, level: 'silver')

        get '/api/v1/loyalty/balance', headers: headers

        expect(response).to have_http_status(:ok)
        expect(json['data']['points']).to eq(250)
        expect(json['data']['level']).to eq('silver')
        expect(json['data']['next_level']).to eq('gold')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/loyalty/balance'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/loyalty/transactions' do
    let!(:account) { create(:loyalty_account, user: user, points: 50) }

    before do
      create_list(:loyalty_transaction, 5, loyalty_account: account)
    end

    context 'when authenticated' do
      it 'returns paginated transactions' do
        get '/api/v1/loyalty/transactions', headers: headers

        expect(response).to have_http_status(:ok)
        expect(json['success']).to be true
        expect(json['data'].length).to eq(5)
        expect(json['meta']['total_count']).to eq(5)
        expect(json['meta']['current_page']).to eq(1)
      end

      it 'supports pagination params' do
        get '/api/v1/loyalty/transactions', params: { page: 1, per_page: 2 }, headers: headers

        expect(response).to have_http_status(:ok)
        expect(json['data'].length).to eq(2)
        expect(json['meta']['per_page']).to eq(2)
        expect(json['meta']['total_pages']).to eq(3)
      end

      it 'returns transactions in descending order' do
        get '/api/v1/loyalty/transactions', headers: headers

        dates = json['data'].map { |t| t['created_at'] }
        expect(dates).to eq(dates.sort.reverse)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/loyalty/transactions'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
