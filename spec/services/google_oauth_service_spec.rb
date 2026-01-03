# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GoogleOAuthService do
  let(:valid_token) { 'valid_google_id_token' }
  let(:invalid_token) { 'invalid_token' }

  let(:google_user_info) do
    {
      'sub' => '123456789',
      'email' => 'test@gmail.com',
      'email_verified' => 'true',
      'given_name' => 'Test',
      'family_name' => 'User',
      'picture' => 'https://example.com/photo.jpg',
      'locale' => 'en',
      'exp' => (Time.now + 1.hour).to_i.to_s,
      'aud' => 'test-client-id'
    }
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GOOGLE_CLIENT_ID').and_return('test-client-id')
  end

  describe '#verify' do
    context 'with valid token' do
      before do
        stub_request(:get, GoogleOAuthService::GOOGLE_TOKEN_INFO_URL)
          .with(query: { id_token: valid_token })
          .to_return(
            status: 200,
            body: google_user_info.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns user info' do
        result = described_class.verify(valid_token)

        expect(result[:provider_user_id]).to eq('123456789')
        expect(result[:email]).to eq('test@gmail.com')
        expect(result[:email_verified]).to be true
        expect(result[:first_name]).to eq('Test')
        expect(result[:last_name]).to eq('User')
      end
    end

    context 'with invalid token' do
      before do
        stub_request(:get, GoogleOAuthService::GOOGLE_TOKEN_INFO_URL)
          .with(query: { id_token: invalid_token })
          .to_return(
            status: 400,
            body: { error: 'invalid_token', error_description: 'Invalid Value' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises InvalidTokenError' do
        expect { described_class.verify(invalid_token) }
          .to raise_error(GoogleOAuthService::InvalidTokenError, 'Invalid Value')
      end
    end

    context 'with expired token' do
      let(:expired_info) { google_user_info.merge('exp' => (Time.now - 1.hour).to_i.to_s) }

      before do
        stub_request(:get, GoogleOAuthService::GOOGLE_TOKEN_INFO_URL)
          .with(query: { id_token: valid_token })
          .to_return(
            status: 200,
            body: expired_info.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises ExpiredTokenError' do
        expect { described_class.verify(valid_token) }
          .to raise_error(GoogleOAuthService::ExpiredTokenError, 'Token has expired')
      end
    end

    context 'with wrong audience' do
      let(:wrong_aud_info) { google_user_info.merge('aud' => 'wrong-client-id') }

      before do
        stub_request(:get, GoogleOAuthService::GOOGLE_TOKEN_INFO_URL)
          .with(query: { id_token: valid_token })
          .to_return(
            status: 200,
            body: wrong_aud_info.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises InvalidAudienceError' do
        expect { described_class.verify(valid_token) }
          .to raise_error(GoogleOAuthService::InvalidAudienceError, 'Invalid token audience')
      end
    end

    context 'when Google API is unavailable' do
      before do
        stub_request(:get, GoogleOAuthService::GOOGLE_TOKEN_INFO_URL)
          .with(query: { id_token: valid_token })
          .to_timeout
      end

      it 'raises TokenVerificationError' do
        expect { described_class.verify(valid_token) }
          .to raise_error(GoogleOAuthService::TokenVerificationError, /Failed to verify token/)
      end
    end
  end
end
