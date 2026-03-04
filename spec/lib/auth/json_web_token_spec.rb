# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::JsonWebToken do
  let(:user_id) { 42 }
  let(:payload) { { user_id: user_id } }

  describe '.encode_access_token' do
    subject(:token) { described_class.encode_access_token(payload) }

    it 'generates a valid JWT string' do
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3)
    end

    it 'includes jti claim in the payload' do
      decoded = JWT.decode(token, described_class.secret_key, true, algorithm: 'HS256').first
      expect(decoded['jti']).to be_present
      expect(decoded['jti']).to match(/\A[0-9a-f-]{36}\z/) # UUID format
    end

    it 'includes token_type=access' do
      decoded = JWT.decode(token, described_class.secret_key, true, algorithm: 'HS256').first
      expect(decoded['token_type']).to eq('access')
    end

    it 'includes iat claim' do
      decoded = JWT.decode(token, described_class.secret_key, true, algorithm: 'HS256').first
      expect(decoded['iat']).to be_a(Integer)
      expect(decoded['iat']).to be_within(5).of(Time.current.to_i)
    end

    it 'generates unique jti for each token' do
      token1 = described_class.encode_access_token(payload)
      token2 = described_class.encode_access_token(payload)

      decoded1 = JWT.decode(token1, described_class.secret_key, true, algorithm: 'HS256').first
      decoded2 = JWT.decode(token2, described_class.secret_key, true, algorithm: 'HS256').first

      expect(decoded1['jti']).not_to eq(decoded2['jti'])
    end

    it 'uses configurable TTL from ENV' do
      allow(ENV).to receive(:fetch).with('JWT_ACCESS_TTL_HOURS', '1').and_return('2')
      allow(ENV).to receive(:fetch).with('JWT_REFRESH_TTL_DAYS', '30').and_return('30')

      decoded = JWT.decode(token, described_class.secret_key, true, algorithm: 'HS256').first
      expected_exp = 2.hours.from_now.to_i
      expect(decoded['exp']).to be_within(5).of(expected_exp)
    end
  end

  describe '.encode_refresh_token' do
    subject(:token) { described_class.encode_refresh_token(payload) }

    it 'generates a valid JWT string' do
      expect(token).to be_a(String)
    end

    it 'includes jti claim in the payload' do
      decoded = JWT.decode(token, described_class.secret_key, true, algorithm: 'HS256').first
      expect(decoded['jti']).to be_present
      expect(decoded['jti']).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'includes token_type=refresh' do
      decoded = JWT.decode(token, described_class.secret_key, true, algorithm: 'HS256').first
      expect(decoded['token_type']).to eq('refresh')
    end

    it 'uses configurable TTL from ENV' do
      allow(ENV).to receive(:fetch).with('JWT_REFRESH_TTL_DAYS', '30').and_return('7')
      allow(ENV).to receive(:fetch).with('JWT_ACCESS_TTL_HOURS', '1').and_return('1')

      decoded = JWT.decode(token, described_class.secret_key, true, algorithm: 'HS256').first
      expected_exp = 7.days.from_now.to_i
      expect(decoded['exp']).to be_within(5).of(expected_exp)
    end
  end

  describe '.encode' do
    subject(:token) { described_class.encode(payload) }

    it 'includes jti claim' do
      decoded = JWT.decode(token, described_class.secret_key, true, algorithm: 'HS256').first
      expect(decoded['jti']).to be_present
    end
  end

  describe '.decode' do
    it 'correctly extracts jti from a decoded token' do
      token = described_class.encode_access_token(payload)

      # Stub blacklist checks to avoid Redis dependency in unit test
      allow(TokenBlacklistService).to receive(:revoked?).and_return(false)
      allow(TokenBlacklistService).to receive(:user_tokens_revoked?).and_return(false)

      decoded = described_class.decode(token)
      expect(decoded[:jti]).to be_present
      expect(decoded[:jti]).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe '.access_token_ttl' do
    it 'defaults to 1 hour when ENV is not set' do
      allow(ENV).to receive(:fetch).with('JWT_ACCESS_TTL_HOURS', '1').and_return('1')
      expect(described_class.access_token_ttl).to eq(1.hour)
    end

    it 'reads from ENV variable' do
      allow(ENV).to receive(:fetch).with('JWT_ACCESS_TTL_HOURS', '1').and_return('4')
      expect(described_class.access_token_ttl).to eq(4.hours)
    end

    it 'falls back to 1 hour for invalid values' do
      allow(ENV).to receive(:fetch).with('JWT_ACCESS_TTL_HOURS', '1').and_return('0')
      expect(described_class.access_token_ttl).to eq(1.hour)
    end
  end

  describe '.refresh_token_ttl' do
    it 'defaults to 30 days when ENV is not set' do
      allow(ENV).to receive(:fetch).with('JWT_REFRESH_TTL_DAYS', '30').and_return('30')
      expect(described_class.refresh_token_ttl).to eq(30.days)
    end

    it 'reads from ENV variable' do
      allow(ENV).to receive(:fetch).with('JWT_REFRESH_TTL_DAYS', '30').and_return('7')
      expect(described_class.refresh_token_ttl).to eq(7.days)
    end

    it 'falls back to 30 days for invalid values' do
      allow(ENV).to receive(:fetch).with('JWT_REFRESH_TTL_DAYS', '30').and_return('-5')
      expect(described_class.refresh_token_ttl).to eq(30.days)
    end
  end
end
