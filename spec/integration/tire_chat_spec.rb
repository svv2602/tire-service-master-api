# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tire Chat Integration', type: :request do
  let(:session_id) { SecureRandom.uuid }
  let(:headers) { { 'Content-Type' => 'application/json', 'X-Session-ID' => session_id } }

  describe 'E2E conversation flow' do
    it 'completes full conversation cycle: send → response → verify history' do
      # Step 1: Send first message
      post '/api/v1/tire_chat/message',
           params: { message: 'Нужны зимние шины 205/55R16', locale: 'ru' }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['conversation_id']).to be_present
      conversation_id = json['conversation_id']

      # Step 2: Send follow-up message in same conversation
      post '/api/v1/tire_chat/message',
           params: { message: 'Покажи бюджетные варианты', locale: 'ru' }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['conversation_id']).to eq(conversation_id)

      # Step 3: Verify history contains all messages
      get '/api/v1/tire_chat/history', headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['messages'].length).to eq(4) # 2 user + 2 assistant
      expect(json['conversation_id']).to eq(conversation_id)

      # Step 4: Verify messages are in correct order
      messages = json['messages']
      expect(messages[0]['role']).to eq('user')
      expect(messages[0]['content']).to include('зимние шины')
      expect(messages[1]['role']).to eq('assistant')
      expect(messages[2]['role']).to eq('user')
      expect(messages[2]['content']).to include('бюджетные')
      expect(messages[3]['role']).to eq('assistant')
    end

    it 'maintains conversation context across messages' do
      # First message sets context (size, season)
      post '/api/v1/tire_chat/message',
           params: { message: 'Ищу зимние шины 195/65R15', locale: 'ru' }.to_json,
           headers: headers

      conversation_id = JSON.parse(response.body)['conversation_id']
      conversation = Conversation.find(conversation_id)

      # Context should be stored in conversation metadata
      expect(conversation.metadata).to be_present

      # Second message should use existing context
      post '/api/v1/tire_chat/message',
           params: { message: 'Покажи премиум бренды', locale: 'ru' }.to_json,
           headers: headers

      # Same conversation should be used
      expect(JSON.parse(response.body)['conversation_id']).to eq(conversation_id)
    end
  end

  describe 'conversation persistence after reload' do
    it 'restores conversation when resuming with same session_id' do
      # Create conversation
      post '/api/v1/tire_chat/message',
           params: { message: 'Нужны летние шины', locale: 'ru' }.to_json,
           headers: headers

      conversation_id = JSON.parse(response.body)['conversation_id']

      # Simulate page reload - get history
      get '/api/v1/tire_chat/history', headers: headers

      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['conversation_id']).to eq(conversation_id)
      expect(json['messages'].length).to eq(2)
    end

    it 'allows resuming specific conversation by ID' do
      # Create first conversation
      post '/api/v1/tire_chat/message',
           params: { message: 'First conversation', locale: 'ru' }.to_json,
           headers: headers

      first_conversation_id = JSON.parse(response.body)['conversation_id']

      # Create second conversation (new session)
      new_session_headers = headers.merge('X-Session-ID' => SecureRandom.uuid)
      post '/api/v1/tire_chat/message',
           params: { message: 'Second conversation', locale: 'ru' }.to_json,
           headers: new_session_headers

      # Resume first conversation
      post "/api/v1/tire_chat/conversations/#{first_conversation_id}/resume",
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['conversation_id']).to eq(first_conversation_id)
      expect(json['messages'].first['content']).to include('First conversation')
    end
  end

  describe 'AI fallback behavior' do
    let(:ai_client) { instance_double(TireChat::AIClient) }

    before do
      allow(TireChat::AIClient).to receive(:new).and_return(ai_client)
      allow(ai_client).to receive(:available?).and_return(true)
    end

    it 'returns fallback response when AI times out' do
      allow(ai_client).to receive(:chat).and_raise(TireChat::AIClient::TimeoutError)

      post '/api/v1/tire_chat/message',
           params: { message: 'Нужны шины', locale: 'ru' }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['response']['is_fallback']).to be true
    end

    it 'returns fallback response when AI rate limited' do
      allow(ai_client).to receive(:chat).and_raise(TireChat::AIClient::RateLimitError)

      post '/api/v1/tire_chat/message',
           params: { message: 'Нужны шины', locale: 'ru' }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['response']['is_fallback']).to be true
    end

    it 'provides useful fallback for seasonal queries' do
      allow(ai_client).to receive(:chat).and_raise(TireChat::AIClient::TimeoutError)

      post '/api/v1/tire_chat/message',
           params: { message: 'Нужны зимние шины', locale: 'ru' }.to_json,
           headers: headers

      json = JSON.parse(response.body)
      expect(json['response']['action']).to include('fallback')
    end
  end

  describe 'streaming response' do
    it 'returns event stream for streaming endpoint' do
      get '/api/v1/tire_chat/stream',
          params: { message: 'Зимние шины', locale: 'ru' },
          headers: headers

      expect(response.content_type).to include('text/event-stream')
    end
  end

  describe 'analytics integration' do
    it 'tracks conversation analytics' do
      expect do
        post '/api/v1/tire_chat/message',
             params: { message: 'Зимние шины 205/55R16', locale: 'ru' }.to_json,
             headers: headers
      end.to change(ChatAnalytic, :count).by(1)

      analytic = ChatAnalytic.last
      expect(analytic.user_query).to include('Зимние шины')
      expect(analytic.response_time_ms).to be_present
    end

    it 'tracks quick questions separately' do
      post '/api/v1/tire_chat/message',
           params: { message: 'Зимние шины', locale: 'ru', is_quick_question: true }.to_json,
           headers: headers

      analytic = ChatAnalytic.last
      expect(analytic.metadata['is_quick_question']).to be true
    end
  end

  describe 'performance with many messages' do
    it 'handles conversation with 20+ messages' do
      10.times do |i|
        post '/api/v1/tire_chat/message',
             params: { message: "Message #{i}", locale: 'ru' }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
      end

      # Verify all messages are stored
      get '/api/v1/tire_chat/history', headers: headers
      json = JSON.parse(response.body)
      expect(json['messages'].length).to eq(20) # 10 user + 10 assistant
    end

    it 'paginates large conversation history efficiently' do
      # Create many messages
      10.times do |i|
        post '/api/v1/tire_chat/message',
             params: { message: "Message #{i}", locale: 'ru' }.to_json,
             headers: headers
      end

      # Get first page
      get '/api/v1/tire_chat/history',
          params: { page: 1, per_page: 5 },
          headers: headers

      json = JSON.parse(response.body)
      expect(json['messages'].length).to eq(5)
      expect(json['pagination']['total']).to eq(20)
      expect(json['pagination']['total_pages']).to eq(4)

      # Get last page
      get '/api/v1/tire_chat/history',
          params: { page: 4, per_page: 5 },
          headers: headers

      json = JSON.parse(response.body)
      expect(json['messages'].length).to eq(5)
    end

    it 'maintains reasonable response time with full context' do
      # Create conversation with multiple messages
      5.times do
        post '/api/v1/tire_chat/message',
             params: { message: 'Test message', locale: 'ru' }.to_json,
             headers: headers
      end

      # Measure response time for next message
      start_time = Time.current
      post '/api/v1/tire_chat/message',
           params: { message: 'Final message', locale: 'ru' }.to_json,
           headers: headers
      elapsed = Time.current - start_time

      expect(response).to have_http_status(:ok)
      # Should respond within reasonable time (5 seconds max for test environment)
      expect(elapsed).to be < 5.seconds
    end
  end

  describe 'multi-language support' do
    it 'responds in Russian when locale is ru' do
      post '/api/v1/tire_chat/message',
           params: { message: 'Нужны шины', locale: 'ru' }.to_json,
           headers: headers

      json = JSON.parse(response.body)
      # Response should be in Russian (contains Cyrillic)
      expect(json['response']['message']).to match(/[а-яА-ЯёЁіІїЇєЄ]/)
    end

    it 'responds in Ukrainian when locale is uk' do
      post '/api/v1/tire_chat/message',
           params: { message: 'Потрібні шини', locale: 'uk' }.to_json,
           headers: headers

      json = JSON.parse(response.body)
      # Response should be in Ukrainian
      expect(json['response']['message']).to match(/[а-яА-ЯіІїЇєЄ]/)
    end
  end
end
