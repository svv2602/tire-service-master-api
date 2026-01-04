# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }
  let(:valid_token) { Auth::JsonWebToken.encode_access_token(user_id: user.id) }
  let(:expired_token) do
    payload = { user_id: user.id, token_type: 'access', exp: 1.hour.ago.to_i }
    JWT.encode(payload, Auth::JsonWebToken.secret_key, 'HS256')
  end
  let(:invalid_token) { 'invalid.jwt.token' }

  describe '#connect' do
    context 'with valid token in query params' do
      it 'successfully connects' do
        connect '/cable', params: { token: valid_token }

        expect(connection.current_user).to eq(user)
      end
    end

    context 'with valid token in cookies' do
      it 'successfully connects' do
        cookies[:access_token] = valid_token
        connect '/cable'

        expect(connection.current_user).to eq(user)
      end
    end

    context 'without any token' do
      it 'rejects the connection' do
        expect { connect '/cable' }.to have_rejected_connection
      end
    end

    context 'with invalid token' do
      it 'rejects the connection' do
        expect { connect '/cable', params: { token: invalid_token } }.to have_rejected_connection
      end
    end

    context 'with expired token' do
      it 'rejects the connection' do
        expect { connect '/cable', params: { token: expired_token } }.to have_rejected_connection
      end
    end

    context 'with token for non-existent user' do
      it 'rejects the connection' do
        deleted_user_token = Auth::JsonWebToken.encode_access_token(user_id: 999_999)
        expect { connect '/cable', params: { token: deleted_user_token } }.to have_rejected_connection
      end
    end

    context 'with inactive user' do
      let(:inactive_user) { create(:user, :inactive) }
      let(:inactive_token) { Auth::JsonWebToken.encode_access_token(user_id: inactive_user.id) }

      it 'rejects the connection' do
        expect { connect '/cable', params: { token: inactive_token } }.to have_rejected_connection
      end
    end
  end

  describe '#disconnect' do
    it 'disconnects without errors' do
      connect '/cable', params: { token: valid_token }

      # Disconnect should not raise any errors
      expect { disconnect }.not_to raise_error
    end
  end

  describe 'token extraction priority' do
    context 'when token is in both query params and cookies' do
      let(:other_user) { create(:user) }
      let(:other_token) { Auth::JsonWebToken.encode_access_token(user_id: other_user.id) }

      it 'prefers query params over cookies' do
        cookies[:access_token] = other_token
        connect '/cable', params: { token: valid_token }

        expect(connection.current_user).to eq(user)
      end
    end
  end
end
