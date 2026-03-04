# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChat::AIClient do
  let(:ai_client) { described_class.new }

  before do
    AiRequestWrapper.reset!
  end

  after do
    AiRequestWrapper.reset!
  end

  describe '#initialize' do
    it 'creates an OpenaiService instance' do
      expect(ai_client.openai_service).to be_a(OpenaiService)
    end

    it 'accepts a custom openai_service' do
      custom_service = instance_double(OpenaiService)
      client = described_class.new(openai_service: custom_service)
      expect(client.openai_service).to eq(custom_service)
    end
  end

  describe '#available?' do
    context 'when OpenAI is configured' do
      before do
        allow(OpenaiService).to receive(:available?).and_return(true)
      end

      it 'returns true' do
        expect(ai_client.available?).to be true
      end
    end

    context 'when OpenAI is not configured' do
      before do
        allow(OpenaiService).to receive(:available?).and_return(false)
      end

      it 'returns false' do
        expect(ai_client.available?).to be false
      end
    end
  end

  describe '#chat' do
    before do
      allow(OpenaiService).to receive(:available?).and_return(true)
    end

    it 'returns nil when OpenAI is not available' do
      allow(OpenaiService).to receive(:available?).and_return(false)
      expect(ai_client.chat('test prompt')).to be_nil
    end

    it 'extracts content from successful response via AiRequestWrapper' do
      response = { 'choices' => [{ 'message' => { 'content' => 'Test response' } }] }
      allow(ai_client.openai_service).to receive(:send).with(:chat_completion, 'test prompt', {}).and_return(response)

      expect(ai_client.chat('test prompt')).to eq('Test response')
    end

    it 'returns nil on error' do
      allow(ai_client.openai_service).to receive(:send).and_raise(StandardError, 'API error')

      expect(ai_client.chat('test prompt')).to be_nil
    end

    it 'uses AiRequestWrapper for resilience' do
      expect(AiRequestWrapper).to receive(:call)
        .with(operation: 'tire_chat_completion')
        .and_return(AiRequestWrapper::Result.new(
                      data: 'AI response content',
                      error: nil,
                      success: true,
                      fallback: false,
                      attempts: 1,
                      latency_ms: 200
                    ))

      result = ai_client.chat('test prompt')
      expect(result).to eq('AI response content')
    end

    it 'returns nil when AiRequestWrapper fails' do
      expect(AiRequestWrapper).to receive(:call)
        .and_return(AiRequestWrapper::Result.new(
                      data: nil,
                      error: 'Timeout::Error: timeout',
                      success: false,
                      fallback: false,
                      attempts: 3,
                      latency_ms: 6000
                    ))

      result = ai_client.chat('test prompt')
      expect(result).to be_nil
    end
  end

  describe '#generate_tire_response' do
    before do
      allow(OpenaiService).to receive(:available?).and_return(true)
    end

    it 'returns fallback message when OpenAI is not available' do
      allow(OpenaiService).to receive(:available?).and_return(false)

      result = ai_client.generate_tire_response('test message', {}, 'ru')
      expect(result).to eq(TireChat::AIClient::FALLBACK_MESSAGE_RU)
    end

    it 'returns Ukrainian fallback when locale is uk' do
      allow(OpenaiService).to receive(:available?).and_return(false)

      result = ai_client.generate_tire_response('test message', {}, 'uk')
      expect(result).to eq(TireChat::AIClient::FALLBACK_MESSAGE_UK)
    end

    it 'calls generate_tire_chat_response via AiRequestWrapper' do
      allow(ai_client.openai_service).to receive(:generate_tire_chat_response).and_return('AI response')

      result = ai_client.generate_tire_response('test message', { size: nil }, 'ru')

      expect(ai_client.openai_service).to have_received(:generate_tire_chat_response).with('test message', { size: nil }, 'ru')
      expect(result).to eq('AI response')
    end

    it 'returns fallback message when circuit breaker is open' do
      expect(AiRequestWrapper).to receive(:call)
        .and_return(AiRequestWrapper::Result.new(
                      data: nil,
                      error: 'Circuit breaker is open',
                      success: false,
                      fallback: true,
                      attempts: 0,
                      latency_ms: 0
                    ))

      result = ai_client.generate_tire_response('test message', {}, 'ru')
      expect(result).to eq(TireChat::AIClient::FALLBACK_MESSAGE_RU)
    end

    it 'preserves chat context during retries' do
      filters = { size: { width: 205, height: 55, diameter: 16 }, season: 'winter' }

      expect(AiRequestWrapper).to receive(:call)
        .with(operation: 'tire_chat_response')
        .and_return(AiRequestWrapper::Result.new(
                      data: 'Response after retry',
                      error: nil,
                      success: true,
                      fallback: false,
                      attempts: 2,
                      latency_ms: 3000
                    ))

      result = ai_client.generate_tire_response('test', filters, 'ru')
      expect(result).to eq('Response after retry')
    end
  end

  describe '#analyze_intent' do
    before do
      allow(OpenaiService).to receive(:available?).and_return(true)
    end

    it 'parses JSON response correctly' do
      response = { 'choices' => [{ 'message' => { 'content' => '{"type": "size_request", "parameters": {}, "confidence": 0.9}' } }] }
      allow(ai_client.openai_service).to receive(:send).and_return(response)

      result = ai_client.analyze_intent('test prompt')

      expect(result[:type]).to eq('size_request')
      expect(result[:confidence]).to eq(0.9)
    end

    it 'handles markdown-wrapped JSON' do
      response = { 'choices' => [{ 'message' => { 'content' => "```json\n{\"type\": \"size_request\"}\n```" } }] }
      allow(ai_client.openai_service).to receive(:send).and_return(response)

      result = ai_client.analyze_intent('test prompt')

      expect(result[:type]).to eq('size_request')
    end

    it 'returns default intent on parse error' do
      response = { 'choices' => [{ 'message' => { 'content' => 'invalid json' } }] }
      allow(ai_client.openai_service).to receive(:send).and_return(response)

      result = ai_client.analyze_intent('test prompt')

      expect(result[:type]).to eq('general_question')
      expect(result[:confidence]).to eq(0.1)
    end
  end

  describe '#fallback_message' do
    it 'returns Russian message by default' do
      expect(ai_client.fallback_message).to include('временно недоступен')
    end

    it 'returns Ukrainian message for uk locale' do
      expect(ai_client.fallback_message('uk')).to include('тимчасово недоступний')
    end
  end
end
