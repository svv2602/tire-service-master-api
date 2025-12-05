# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChat::AIClient do
  let(:ai_client) { described_class.new }

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

    it 'extracts content from successful response' do
      response = { 'choices' => [{ 'message' => { 'content' => 'Test response' } }] }
      allow(ai_client.openai_service).to receive(:send).with(:chat_completion, 'test prompt', {}).and_return(response)

      expect(ai_client.chat('test prompt')).to eq('Test response')
    end

    it 'returns nil on error' do
      allow(ai_client.openai_service).to receive(:send).and_raise(StandardError, 'API error')

      expect(ai_client.chat('test prompt')).to be_nil
    end
  end

  describe '#generate_tire_response' do
    before do
      allow(OpenaiService).to receive(:available?).and_return(true)
    end

    it 'returns nil when OpenAI is not available' do
      allow(OpenaiService).to receive(:available?).and_return(false)
      expect(ai_client.generate_tire_response('test message')).to be_nil
    end

    it 'calls generate_tire_chat_response on openai_service' do
      allow(ai_client.openai_service).to receive(:generate_tire_chat_response).and_return('AI response')

      result = ai_client.generate_tire_response('test message', { size: nil }, 'ru')

      expect(ai_client.openai_service).to have_received(:generate_tire_chat_response).with('test message', { size: nil }, 'ru')
      expect(result).to eq('AI response')
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
end
