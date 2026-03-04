# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiVersionMiddleware do
  let(:app) { ->(env) { [200, {}, ['OK']] } }
  let(:middleware) { described_class.new(app) }

  describe '#call' do
    it 'sets default API-Version header when none requested' do
      env = Rack::MockRequest.env_for('/')
      status, headers, _body = middleware.call(env)

      expect(status).to eq(200)
      expect(headers['API-Version']).to eq('1')
    end

    it 'echoes back the requested API-Version when supported' do
      env = Rack::MockRequest.env_for('/', 'HTTP_API_VERSION' => '1')
      _status, headers, _body = middleware.call(env)

      expect(headers['API-Version']).to eq('1')
    end

    it 'falls back to current version when unsupported version requested' do
      env = Rack::MockRequest.env_for('/', 'HTTP_API_VERSION' => '99')
      _status, headers, _body = middleware.call(env)

      expect(headers['API-Version']).to eq('1')
    end

    it 'stores version in request env for controller access' do
      env = Rack::MockRequest.env_for('/', 'HTTP_API_VERSION' => '1')
      middleware.call(env)

      expect(env['api.version']).to eq('1')
    end
  end
end
